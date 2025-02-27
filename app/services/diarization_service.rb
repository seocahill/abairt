# frozen_string_literal: true

class DiarizationService
  def initialize(voice_recording)
    @voice_recording = voice_recording
    @api_key = Rails.env.test? ? "test_key" : Rails.application.credentials.dig(:pyannote, :api_key)
    @base_url = "https://api.pyannote.ai/v1"
  end

  def diarize
    return unless @voice_recording.media.attached?

    media_url = Rails.application.routes.url_helpers.url_for(@voice_recording.extract_audio_track)

    # Get the ngrok URL from environment or fall back to production URL
    base_url = Rails.env.development? ? ENV['WEBHOOK_URL'] : "https://abairt.com"

    # Don't include port if using ngrok
    url_options = {
      host: base_url,
      protocol: 'https',
      port: nil
    }

    webhook_url = Rails.application.routes.url_helpers.api_voice_recording_diarization_webhook_url(
      @voice_recording,
      **url_options
    )

    # Make the API request with converted audio URL
    response = HTTParty.post(
      "#{@base_url}/diarize",
      headers: {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json"
      },
      body: {
        webhook: webhook_url,
        url: media_url
      }.to_json
    )

    if response.success?
      @voice_recording.update(
        diarization_status: 'pending',
        diarization_data: { job_id: response['jobId'] }
      )
      true
    else
      Rails.logger.error("Diarization API error: #{response.body}")
      false
    end
  rescue => e
    Rails.logger.error("Diarization service error: #{e.message}")
    false
  end

  def handle_webhook(payload)
    return unless payload['jobId'] == @voice_recording&.diarization_data&.dig('job_id')

    if payload['status'] == 'succeeded'
      @voice_recording.update(
        diarization_status: 'completed',
        diarization_data: payload['output']
      )

      CreateSpeakerEntriesJob.perform_later(@voice_recording.id)
      true
    else
      @voice_recording.update(diarization_status: 'failed')
      false
    end
  end

  def create_speaker_entries
    return unless @voice_recording.diarization_data.present?

    diarization_segments = @voice_recording.diarization_data['diarization']
    temp_path = "/tmp/voice_recording_#{@voice_recording.id}#{File.extname(@voice_recording.media.filename.to_s)}"

    begin
      unless File.exist?(temp_path)
        File.open(temp_path, 'wb') do |file|
          @voice_recording.media.download do |chunk|
            file.write(chunk)
          end
        end
      end

      speakers = diarization_segments.map { |segment| segment['speaker'] }.uniq
      speakers.each do |speaker_id|
        name = "#{speaker_id}_#{@voice_recording.id}"
        temp_user = User.find_or_create_by(email: "#{name.downcase}@temporary.abairt") do |user|
          user.name = name
          user.password = SecureRandom.hex(16)
          user.role = :temporary
        end

        speaker_segments = diarization_segments.select { |segment| segment['speaker'] == speaker_id }
        speaker_segments.each do |segment|
          entry = DictionaryEntry.create!(
            speaker: temp_user,
            voice_recording: @voice_recording,
            owner: @voice_recording.owner,
            region_start: segment['start'],
            region_end: segment['end']
          )

          entry.create_audio_snippet(temp_path)
        end
      end
    ensure
      File.delete temp_path rescue nil
    end
  end

  private


end
