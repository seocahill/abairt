# frozen_string_literal: true

class TranscriptionCorrectionService
  def initialize(voice_recording)
    @voice_recording = voice_recording
    @client = openai_client
  end

  def correct_transcriptions
    return false unless @voice_recording.transcription.present?
    return false if @voice_recording.dictionary_entries.empty?

    # Get all diarized segments in chronological order
    segments = @voice_recording.dictionary_entries.order(:region_start).map do |entry|
      {
        id: entry.id,
        start: entry.region_start,
        end: entry.region_end,
        current_text: entry.word_or_phrase,
        current_translation: entry.translation
      }
    end

    # Request corrections from OpenAI
    response = request_corrections(segments)
    return false unless response.present?

    # Update entries with corrections
    update_entries(response)
    true
  rescue => e
    Rails.logger.error("Failed to correct transcriptions for recording #{@voice_recording.id}: #{e.message}")
    Sentry.capture_exception(e)
    false
  end

  private

  attr_reader :voice_recording, :client

  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )
  end

  def request_corrections(segments)
    prompt = <<~PROMPT
      I have a voice recording with the following full transcription:
      "#{voice_recording.transcription}"

      And its English translation:
      "#{voice_recording.transcription_en}"

      The recording has been diarized into the following segments:
      #{segments.to_json}

      Please analyze each segment and provide corrections if needed. For each segment:
      1. Compare the current text with the corresponding part of the full transcription
      2. If there are differences, provide the corrected text and translation
      3. If the current text is accurate, keep it as is
      4. If a segment is missing text, provide the text from the full transcription

      Return a JSON array of objects with the following structure:
      {
        "id": "segment_id",
        "corrected_text": "corrected Irish text or null if no correction needed",
        "corrected_translation": "corrected English translation or null if no correction needed",
        "confidence": "high/medium/low indicating confidence in the correction"
      }
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4",
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You are an expert linguist specializing in Irish Gaelic. Analyze the diarized segments and provide corrections based on the full transcription. Return a JSON object with an array of corrections."
          },
          { role: "user", content: prompt }
        ],
        temperature: 0.3
      }
    )

    JSON.parse(response.dig("choices", 0, "message", "content"))["corrections"]
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse OpenAI response: #{e.message}")
    nil
  end

  def update_entries(corrections)
    corrections.each do |correction|
      entry = voice_recording.dictionary_entries.find(correction["id"])
      next unless entry

      if correction["corrected_text"].present?
        entry.update_columns(
          word_or_phrase: correction["corrected_text"],
          translation: correction["corrected_translation"] || entry.translation
        )
      end
    end
  end
end 