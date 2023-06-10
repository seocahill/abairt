class GeneratePeaksJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id)
    VoiceRecording.find(voice_recording_id).generate_peaks
  end
end
