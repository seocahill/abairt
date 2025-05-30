class VoiceRecordings::ImportsController < ApplicationController
  def new
    authorize VoiceRecording
  end

  def create
    authorize VoiceRecording
    voice_recording = Importers::CanuintIe.import(params[:url])
    redirect_to voice_recording_path(voice_recording), notice: "Voice recording imported successfully"
  rescue StandardError => e
    redirect_to new_voice_recording_import_path, alert: "Failed to import voice recording: #{e.message}"
  end
end
