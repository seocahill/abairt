# frozen_string_literal: true

# Job to process Fotheidil videos using the ProcessVideoOperation
class ProcessFotheidilVideoJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id, fotheidil_video_id = nil)
    voice_recording = VoiceRecording.find(voice_recording_id)

    result = Fotheidil::ProcessVideoOperation.call(
      voice_recording: voice_recording,
      fotheidil_video_id: fotheidil_video_id
    )

    unless result.success?
      Rails.logger.error "ProcessFotheidilVideoJob failed: #{result[:error]}"
    end
  end
end
