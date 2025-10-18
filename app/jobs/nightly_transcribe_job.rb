class NightlyTranscribeJob < ApplicationJob
  queue_as :default

  def perform
    # Find the last voice recording that hasn't been diarized yet
    voice_recording = VoiceRecording
      .joins(:media_attachment)
      .where(diarization_status: [nil, 'not_started', 'failed'])
      .order(created_at: :desc)
      .first

    voice_recording ||= VoiceRecording.import_from_archive

    return unless voice_recording

    Rails.logger.info("Starting nightly Fotheidil processing for VoiceRecording #{voice_recording.id}")

    # Use Fotheidil process for nightly imports (no video_id = upload to Fotheidil)
    ProcessFotheidilVideoJob.perform_later(voice_recording.id, nil)
  end
end