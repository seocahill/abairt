# frozen_string_literal: true

require 'open-uri'
require 'json'

class ArchiveImportService
  def initialize(media_file_path: nil)
    @media_file_path = media_file_path || Rails.root.join('lib', 'assets', 'media.json')
  end

  def import_next_recording
    return nil unless File.exist?(@media_file_path)

    media_data = load_media_data
    unimported_item = find_unimported_item(media_data)
    return nil unless unimported_item

    generated_name = generate_unique_name(unimported_item['title'], unimported_item['headline'])
    
    # Check for existing recording
    existing_recording = VoiceRecording.find_by(title: generated_name)
    if existing_recording
      mark_as_imported(media_data, unimported_item)
      return existing_recording
    end

    create_voice_recording(unimported_item, generated_name, media_data)
  end

  private

  def load_media_data
    JSON.parse(File.read(@media_file_path))
  end

  def find_unimported_item(media_data)
    media_data.find { |item| !item['imported'] }
  end

  def generate_unique_name(title, headline)
    combined = "#{title} - #{headline}".strip
    combined.length > 255 ? combined[0..251] + "..." : combined
  end

  def create_voice_recording(item, generated_name, media_data)
    voice_recording = VoiceRecording.create!(
      title: generated_name,
      description: item['description'],
      owner: User.first || User.create!(email: 'test@example.com', password: 'password')
    )

    download_and_attach_media(voice_recording, item['url']) if item['url'].present?
    mark_as_imported(media_data, item)

    Rails.logger.info("Successfully imported voice recording: #{generated_name}")
    voice_recording
  rescue StandardError => e
    Rails.logger.error("Failed to import voice recording: #{e.message}")
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

  def mark_as_imported(media_data, item)
    item_index = media_data.index(item)
    return unless item_index

    media_data[item_index]['imported'] = true
    File.write(@media_file_path, JSON.pretty_generate(media_data))
  end
end 