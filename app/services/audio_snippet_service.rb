class AudioSnippetService

  def initialize(dictionary_entry, source_file_path = nil)
    @entry = dictionary_entry
    @source_file_path = source_file_path
    @voice_recording = dictionary_entry.voice_recording
    @duration = dictionary_entry.region_end - dictionary_entry.region_start
    @output_path = "/tmp/#{dictionary_entry.id}.mp3"
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

    @entry.media.attach(io: File.open(@output_path), filename: "#{@entry.id}.mp3")
    @output_path
  end

  private

  def process_audio_segment(input_path)
    require 'open3'

    codec_args = @voice_recording.media.audio? ? ["-c:a", "copy"] : ["-vn"]
    command = ["ffmpeg", "-ss", @entry.region_start.to_s, "-i", input_path.to_s, "-t", @duration.to_s, *codec_args, @output_path.to_s]

    _stdout, stderr, status = Open3.capture3(*command)

    unless status.success?
      Rails.logger.error("FFmpeg error: #{stderr}")
      raise "Failed to process audio segment: #{stderr}"
    end
  end
end
