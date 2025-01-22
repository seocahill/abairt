class CreateSpeakerEntriesJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id)
    voice_recording = VoiceRecording.find(voice_recording_id)
    return unless voice_recording.diarization_data.present?

    service = DiarizationService.new(voice_recording)
    service.create_speaker_entries
  end
end
