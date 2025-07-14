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

    Rails.logger.info("Starting nightly diarization for VoiceRecording #{voice_recording.id}")
    
    # Start diarization process
    DiarizationService.new(voice_recording).diarize
  end
end