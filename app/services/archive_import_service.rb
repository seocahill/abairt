# frozen_string_literal: true

require 'open-uri'
require 'json'

class ArchiveImportService
  def initialize
    # No longer need media_file_path since we use MediaImport table
  end

  def import_next_recording
    # Find the next pending MediaImport item
    media_import = MediaImport.pending.first
    return nil unless media_import

    generated_name = generate_unique_name(media_import.title, media_import.headline)
    
    # Check for existing recording
    existing_recording = VoiceRecording.find_by(title: generated_name)
    if existing_recording
      media_import.mark_as_imported!
      return existing_recording
    end

    create_voice_recording(media_import, generated_name)
  end

  def import_specific_recording(media_import_id)
    media_import = MediaImport.find(media_import_id)
    return nil unless media_import.pending?

    generated_name = generate_unique_name(media_import.title, media_import.headline)
    
    # Check for existing recording
    existing_recording = VoiceRecording.find_by(title: generated_name)
    if existing_recording
      media_import.mark_as_imported!
      return existing_recording
    end

    create_voice_recording(media_import, generated_name)
  end

  private

  def generate_unique_name(title, headline)
    combined = "#{title} - #{headline}".strip
    combined.length > 255 ? combined[0..251] + "..." : combined
  end

  def create_voice_recording(media_import, generated_name)
    voice_recording = VoiceRecording.create!(
      title: generated_name,
      description: media_import.description,
      owner: User.first || User.create!(email: 'test@example.com', password: 'password')
    )

    download_and_attach_media(voice_recording, media_import.url) if media_import.url.present?
    media_import.mark_as_imported!

    Rails.logger.info("Successfully imported voice recording: #{generated_name}")
    voice_recording
  rescue StandardError => e
    Rails.logger.error("Failed to import voice recording: #{e.message}")
    media_import.mark_as_failed!(e.message)
    voice_recording&.destroy
    nil
  end

  def download_and_attach_media(voice_recording, url)
    temp_file = URI.open(url)
    
    content_type = temp_file.content_type || 'audio/mpeg'
    filename = extract_filename(url)

    # Create a StringIO to make it rewindable for Active Storage
    rewindable_io = StringIO.new(temp_file.read)
    rewindable_io.rewind

    voice_recording.media.attach(
      io: rewindable_io,
      filename: filename,
      content_type: content_type
    )

    calculate_duration(voice_recording, rewindable_io, content_type, filename)
  rescue StandardError => e
    Rails.logger.error("Failed to download media from #{url}: #{e.message}")
    raise
  end

  def extract_filename(url)
    filename = File.basename(URI.parse(url).path)
    (filename.present? && filename != "/") ? filename : "archive_#{SecureRandom.hex(16)}.mp3"
  end

  def calculate_duration(voice_recording, rewindable_io, content_type, filename)
    return unless content_type.start_with?('audio/', 'video/')

    temp_path = "/tmp/#{SecureRandom.hex(8)}#{File.extname(filename)}"
    
    rewindable_io.rewind
    File.open(temp_path, 'wb') { |f| f.write(rewindable_io.read) }
    duration = voice_recording.calculate_duration(temp_path)
    voice_recording.update(duration_seconds: duration) if duration&.positive?
  ensure
    File.delete(temp_path) if temp_path && File.exist?(temp_path)
  end

end 