class NightlyTranscribeJob < ApplicationJob
  queue_as :default

  def perform
    # Check if required services are operational before proceeding
    return unless services_operational?

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

  private

  def services_operational?
    # Check if ASR (speech recognition) service is up
    asr_up = ServiceStatus.is_up?('asr')
    
    # Check if Pyannote (speaker diarization) service is up
    pyannote_up = ServiceStatus.is_up?('pyannote')
    
    # Both services need to be operational for diarization to work
    services_operational = asr_up && pyannote_up
    
    Rails.logger.info("Service status check - ASR: #{asr_up ? 'UP' : 'DOWN'}, Pyannote: #{pyannote_up ? 'UP' : 'DOWN'}")
    
    services_operational
  end
end