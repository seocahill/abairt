# frozen_string_literal: true

class CorrectTranscriptionsJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id)
    voice_recording = VoiceRecording.find_by(id: voice_recording_id)
    return unless voice_recording

    service = TranscriptionCorrectionService.new(voice_recording)
    service.correct_transcriptions
  end
end 