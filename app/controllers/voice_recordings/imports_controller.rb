class VoiceRecordings::ImportsController < ApplicationController
  def new
    authorize VoiceRecording
  end

  def create
    authorize VoiceRecording
    
    url = params[:url]
    title = params[:title].present? ? params[:title] : nil
    
    # Create placeholder record immediately
    placeholder_title = title || "Importing from #{URI.parse(url).host}..."
    voice_recording = VoiceRecording.create!(
      title: placeholder_title,
      owner: current_user,
      import_status: 'pending'
    )
    
    # Queue the import job
    importer_class = if url.include?('rte.ie')
                       'Importers::RteIe'
                     elsif url.include?('canuint.ie')
                       'Importers::CanuintIe'
                     else
                       raise "Unsupported URL. Please use a URL from rte.ie or canuint.ie"
                     end
    
    ImportVoiceRecordingJob.perform_later(voice_recording.id, url, importer_class, title: title)
                      
    redirect_to voice_recording_path(voice_recording), notice: "Import started! Your recording will be available shortly."
  rescue StandardError => e
    redirect_to new_import_path, alert: "Failed to start import: #{e.message}"
  end
end
