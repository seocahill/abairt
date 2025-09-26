class ProcessMediaImportJob < ApplicationJob
  queue_as :default

  def perform(media_import_id)
    media_import = MediaImport.find(media_import_id)
    
    # Skip if not pending
    unless media_import.pending?
      Rails.logger.info "MediaImport #{media_import_id} is not pending, skipping"
      return
    end

    Rails.logger.info "Processing MediaImport #{media_import_id}: #{media_import.title}"
    
    # Import the voice recording
    voice_recording = VoiceRecording.import_from_media_import(media_import_id)
    
    if voice_recording
      Rails.logger.info "Successfully processed MediaImport #{media_import_id} -> VoiceRecording #{voice_recording.id}"
    else
      Rails.logger.error "Failed to process MediaImport #{media_import_id}"
    end
  rescue => e
    Rails.logger.error "ProcessMediaImportJob failed for MediaImport #{media_import_id}: #{e.message}"
    # The error handling is already done in ArchiveImportService
    raise e
  end
end
