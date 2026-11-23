# frozen_string_literal: true

# Job to process Fotheidil videos using the ProcessVideoOperation
class ProcessFotheidilVideoJob < ApplicationJob
  queue_as :default

  # One Fotheidil job at a time, shared with TranscriptionRerunJob so the two
  # don't pile onto Abair together. Processing can take over 30 minutes, so
  # hold the slot long enough to cover it.
  limits_concurrency to: 1, key: "fotheidil_browser", group: "fotheidil", duration: 1.hour

  def perform(voice_recording_id, fotheidil_video_id = nil)
    voice_recording = VoiceRecording.find(voice_recording_id)

    result = Fotheidil::ProcessVideoOperation.call(
      voice_recording: voice_recording,
      fotheidil_video_id: fotheidil_video_id
    )

    unless result.success?
      error_message = result[:error]
      Rails.logger.error "ProcessFotheidilVideoJob failed: #{error_message}"
      NotificationsMailer.transcription_failed(voice_recording, error_message).deliver_later
    end
  end
end
