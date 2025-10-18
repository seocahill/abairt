# frozen_string_literal: true

require "open-uri"
require "json"

# Handles importing media from archive to VoiceRecordings
# Processes MediaImport records and creates corresponding VoiceRecordings
class ArchiveImportService
  def import_next_recording
    MediaImport.pending.find_each do |media_import|
      generated_name = generate_unique_name(media_import.title, media_import.headline)

      existing_recording = VoiceRecording.find_by(title: generated_name)
      if existing_recording
        media_import.mark_as_imported!
        next if existing_recording.diarization_status == "completed"
        return existing_recording
      end

      return create_voice_recording(media_import, generated_name)
    end

    nil
  end

  def import_specific_recording(media_import_id)
    media_import = MediaImport.find(media_import_id)
    return nil unless media_import.pending?

    generated_name = generate_unique_name(media_import.title, media_import.headline)

    existing_recording = handle_existing_recording(media_import, generated_name)
    return existing_recording if existing_recording

    create_voice_recording(media_import, generated_name)
  end

  private

  def handle_existing_recording(media_import, generated_name)
    existing_recording = VoiceRecording.find_by(title: generated_name)
    return nil unless existing_recording

    media_import.mark_as_imported!
    return nil if existing_recording.diarization_status == "completed"

    existing_recording
  end

  def generate_unique_name(title, headline)
    combined = "#{title} - #{headline}".strip
    (combined.length > 255) ? "#{combined[0..251]}..." : combined
  end

  def create_voice_recording(media_import, generated_name)
    voice_recording = VoiceRecording.create!(
      title: generated_name,
      description: media_import.description,
      owner: find_or_create_owner
    )

    download_and_attach_media(voice_recording, media_import.url) if media_import.url.present?
    media_import.mark_as_imported!

    Rails.logger.info("Successfully imported voice recording: #{generated_name}")
    voice_recording
  rescue => e
    handle_import_failure(media_import, voice_recording, e)
  end

  def handle_import_failure(media_import, voice_recording, error)
    Rails.logger.error("Failed to import voice recording: #{error.message}")
    media_import.mark_as_failed!(error.message)
    voice_recording&.destroy
    nil
  end

  def find_or_create_owner
    User.first || User.create!(email: "test@example.com", password: "password")
  end

  def download_and_attach_media(voice_recording, url)
    temp_file = URI.open(url) # standard:disable Security/Open

    content_type = temp_file.content_type || "audio/mpeg"
    filename = extract_filename(url)

    rewindable_io = create_rewindable_io(temp_file)

    voice_recording.media.attach(
      io: rewindable_io,
      filename: filename,
      content_type: content_type
    )

    calculate_duration(voice_recording, rewindable_io, content_type, filename)
  rescue => e
    Rails.logger.error("Failed to download media from #{url}: #{e.message}")
    raise
  end

  def create_rewindable_io(temp_file)
    rewindable_io = StringIO.new(temp_file.read)
    rewindable_io.rewind
    rewindable_io
  end

  def extract_filename(url)
    filename = File.basename(URI.parse(url).path)
    (filename.present? && filename != "/") ? filename : "archive_#{SecureRandom.hex(16)}.mp3"
  end

  def calculate_duration(voice_recording, rewindable_io, content_type, filename)
    return unless content_type.start_with?("audio/", "video/")

    temp_path = "/tmp/#{SecureRandom.hex(8)}#{File.extname(filename)}"

    write_temp_file(rewindable_io, temp_path)
    update_duration(voice_recording, temp_path)
  ensure
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
  end

  def write_temp_file(rewindable_io, temp_path)
    rewindable_io.rewind
    File.binwrite(temp_path, rewindable_io.read)
  end

  def update_duration(voice_recording, temp_path)
    duration = voice_recording.calculate_duration(temp_path)
    voice_recording.update(duration_seconds: duration) if duration&.positive?
  end
end
