# frozen_string_literal: true

# Trailblazer operation for importing media from MediaImport to VoiceRecording
# Composes Fotheidil::ProcessVideoOperation for processing
#
# Usage:
#   result = ImportMediaOperation.call(media_import_id: 123)
#
#   if result.success?
#     result[:voice_recording] # Created and processed voice recording
#   else
#     result[:error] # Error message
#   end
class ImportMediaOperation < Trailblazer::Operation
  step :load_media_import
  step :check_pending_status, Output(:failure) => End(:not_pending)
  step :generate_unique_name
  step :check_existing_recording
  step :find_or_create_owner
  step :create_voice_recording
  step :download_and_attach_media
  step :mark_as_imported
  step Subprocess(Fotheidil::ProcessVideoOperation)
  fail :mark_import_as_failed
  fail :cleanup_voice_recording

  # Load the MediaImport record
  def load_media_import(ctx, media_import_id:, **)
    media_import = MediaImport.find_by(id: media_import_id)

    unless media_import
      ctx[:error] = "MediaImport #{media_import_id} not found"
      return false
    end

    ctx[:media_import] = media_import
    true
  rescue => e
    ctx[:error] = "Failed to load MediaImport: #{e.message}"
    false
  end

  # Check if MediaImport is pending
  def check_pending_status(ctx, media_import:, **)
    unless media_import.pending?
      ctx[:error] = "MediaImport is not pending (status: #{media_import.status})"
      Rails.logger.info "MediaImport #{media_import.id} is not pending, skipping"
      return false
    end

    true
  end

  # Generate unique name from title and headline
  def generate_unique_name(ctx, media_import:, **)
    combined = "#{media_import.title} - #{media_import.headline}".strip
    ctx[:generated_name] = (combined.length > 255) ? "#{combined[0..251]}..." : combined
    true
  end

  # Check if recording already exists
  def check_existing_recording(ctx, generated_name:, media_import:, **)
    existing_recording = VoiceRecording.find_by(title: generated_name)

    if existing_recording
      media_import.mark_as_imported!

      if existing_recording.diarization_status == "completed"
        ctx[:voice_recording] = existing_recording
        ctx[:error] = "Recording already exists and is completed"
        return false
      end

      # Return existing recording for reprocessing
      ctx[:voice_recording] = existing_recording
      ctx[:skip_creation] = true
    end

    true
  end

  # Find or create owner for voice recording
  def find_or_create_owner(ctx, skip_creation: false, **)
    return true if skip_creation

    owner = User.first || User.create!(email: "test@example.com", password: "password")
    ctx[:owner] = owner
    true
  rescue => e
    ctx[:error] = "Failed to find/create owner: #{e.message}"
    false
  end

  # Create VoiceRecording from MediaImport
  def create_voice_recording(ctx, skip_creation: false, media_import:, generated_name:, owner: nil, **)
    return true if skip_creation

    voice_recording = VoiceRecording.create!(
      title: generated_name,
      description: media_import.description,
      owner: owner
    )

    ctx[:voice_recording] = voice_recording
    Rails.logger.info "Created VoiceRecording #{voice_recording.id}: #{generated_name}"
    true
  rescue => e
    ctx[:error] = "Failed to create voice recording: #{e.message}"
    Rails.logger.error "Create error: #{e.message}"
    false
  end

  # Download and attach media from MediaImport URL
  def download_and_attach_media(ctx, skip_creation: false, voice_recording:, media_import:, **)
    return true if skip_creation
    return true if media_import.url.blank?

    Rails.logger.info "Downloading media from #{media_import.url}"

    temp_file = URI.open(media_import.url) # standard:disable Security/Open
    content_type = temp_file.content_type || "audio/mpeg"
    filename = extract_filename(media_import.url)

    rewindable_io = StringIO.new(temp_file.read)
    rewindable_io.rewind

    voice_recording.media.attach(
      io: rewindable_io,
      filename: filename,
      content_type: content_type
    )

    calculate_duration(voice_recording, rewindable_io, content_type, filename)

    Rails.logger.info "Media attached successfully"
    true
  rescue => e
    ctx[:error] = "Failed to download media: #{e.message}"
    Rails.logger.error "Download error: #{e.message}"
    false
  end

  # Mark MediaImport as imported
  def mark_as_imported(ctx, media_import:, **)
    media_import.mark_as_imported!
    Rails.logger.info "Marked MediaImport #{media_import.id} as imported"
    true
  rescue => e
    ctx[:error] = "Failed to mark as imported: #{e.message}"
    false
  end

  # Mark MediaImport as failed
  def mark_import_as_failed(ctx, media_import: nil, error: nil, **)
    return true unless media_import

    error_message = error || "Import failed"
    media_import.mark_as_failed!(error_message)
    Rails.logger.error "MediaImport #{media_import.id} marked as failed: #{error_message}"
    true
  end

  # Cleanup voice recording on failure
  def cleanup_voice_recording(ctx, voice_recording: nil, skip_creation: false, **)
    return true if skip_creation
    return true unless voice_recording

    voice_recording.destroy
    Rails.logger.info "Cleaned up VoiceRecording #{voice_recording.id}"
    true
  rescue => e
    Rails.logger.error "Failed to cleanup voice recording: #{e.message}"
    true # Don't fail the operation on cleanup errors
  end

  private

  def extract_filename(url)
    filename = File.basename(URI.parse(url).path)
    (filename.present? && filename != "/") ? filename : "archive_#{SecureRandom.hex(16)}.mp3"
  end

  def calculate_duration(voice_recording, rewindable_io, content_type, filename)
    return unless content_type.start_with?("audio/", "video/")

    temp_path = "/tmp/#{SecureRandom.hex(8)}#{File.extname(filename)}"

    rewindable_io.rewind
    File.binwrite(temp_path, rewindable_io.read)

    duration = voice_recording.calculate_duration(temp_path)
    voice_recording.update(duration_seconds: duration) if duration&.positive?
  ensure
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
  end
end
