class AudioSnippetService

  def initialize(dictionary_entry, source_file_path = nil)
    @entry = dictionary_entry
    @source_file_path = source_file_path
    @voice_recording = dictionary_entry.voice_recording
    @duration = dictionary_entry.region_end - dictionary_entry.region_start
    @output_path = "/tmp/#{dictionary_entry.region_id}.mp3"
  end

  def process
    return unless @voice_recording

    File.delete @output_path rescue nil

    if @source_file_path && File.exist?(@source_file_path)
      process_audio_segment(@source_file_path)
    else
      @voice_recording.media.open do |file|
        process_audio_segment(file.path)
      end
    end

    @entry.media.attach(io: File.open(@output_path), filename: "#{@entry.region_id}.mp3")
    @output_path
  end

  private

  def process_audio_segment(input_path)
    require 'open3'

    command = if @voice_recording.media.audio?
      "ffmpeg -ss #{@entry.region_start} -i #{input_path} -t #{@duration} -c:a copy #{@output_path}"
    else
      "ffmpeg -ss #{@entry.region_start} -i #{input_path} -t #{@duration} -vn #{@output_path}"
    end

    stdout, stderr, status = Open3.capture3(command)

    unless status.success?
      Rails.logger.error("FFmpeg error: #{stderr}")
      raise "Failed to process audio segment: #{stderr}"
    end
  end
end
