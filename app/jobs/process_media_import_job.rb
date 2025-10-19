class ProcessMediaImportJob < ApplicationJob
  queue_as :default

  def perform(media_import_id)
    Rails.logger.info "Processing MediaImport #{media_import_id}"

    result = ImportMediaOperation.call(media_import_id: media_import_id)

    if result.success?
      voice_recording = result[:voice_recording]
      Rails.logger.info "Successfully processed MediaImport #{media_import_id} -> VoiceRecording #{voice_recording.id}"
    else
      Rails.logger.error "Failed to process MediaImport #{media_import_id}: #{result[:error]}"
    end
  rescue => e
    Rails.logger.error "ProcessMediaImportJob failed for MediaImport #{media_import_id}: #{e.message}"
    raise e
  end
end
