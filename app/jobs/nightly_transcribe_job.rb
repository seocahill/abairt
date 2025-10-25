class NightlyTranscribeJob < ApplicationJob
  queue_as :default

  def perform
    voice_recording = VoiceRecording.import_from_archive

    return unless voice_recording

    Rails.logger.info("Starting nightly Fotheidil processing for VoiceRecording #{voice_recording.id}")

    # Use Fotheidil process for nightly imports (no video_id = upload to Fotheidil)
    ProcessFotheidilVideoJob.perform_later(voice_recording.id, nil)
  end
end