class ImportVoiceRecordingJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id, url, importer_class, title: nil)
    voice_recording = VoiceRecording.find(voice_recording_id)
    
    begin
      voice_recording.update!(import_status: 'processing')
      
      # Call the importer's import_to_record method (we need to modify importers)
      if importer_class == 'Importers::RteIe'
        Importers::RteIe.import_to_record(voice_recording, url, title: title)
      elsif importer_class == 'Importers::CanuintIe'
        Importers::CanuintIe.import_to_record(voice_recording, url)
      end
      
      voice_recording.update!(import_status: 'completed')
      Rails.logger.info "Voice recording import completed for ID: #{voice_recording.id}"
      
    rescue => e
      voice_recording.update!(import_status: 'failed')
      Rails.logger.error "Voice recording import failed for ID: #{voice_recording.id} - #{e.message}"
      raise e
    end
  end
end
