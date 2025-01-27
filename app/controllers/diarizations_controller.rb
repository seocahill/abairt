class DiarizationsController < ApplicationController
  def create
    @voice_recording = VoiceRecording.find(params[:voice_recording_id])
    authorize @voice_recording

    service = DiarizationService.new(@voice_recording)
    if service.diarize
      respond_to do |format|
        format.html { redirect_to @voice_recording, notice: 'Diarization started successfully. This may take a few minutes depending on the length of the recording. You can refresh this page to see the status.' }
      end
    else
      respond_to do |format|
        format.html { redirect_to @voice_recording, alert: 'Failed to start diarization.' }
      end
    end
  end
end
