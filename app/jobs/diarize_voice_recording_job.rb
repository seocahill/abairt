class DiarizeVoiceRecordingJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id)
    voice_recording = VoiceRecording.find(voice_recording_id)
    DiarizationService.new(voice_recording).diarize
  end
end
