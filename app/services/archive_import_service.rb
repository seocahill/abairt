# frozen_string_literal: true

# Handles importing media from archive to VoiceRecordings
# Delegates to ImportMediaOperation for processing
class ArchiveImportService
  def import_next_recording
    media_import = MediaImport.pending.first
    return nil unless media_import

    import_specific_recording(media_import.id)
  end

  def import_specific_recording(media_import_id)
    result = ImportMediaOperation.call(media_import_id: media_import_id)

    if result.success?
      result[:voice_recording]
    else
      Rails.logger.error("Import failed: #{result[:error]}")
      nil
    end
  end
end
