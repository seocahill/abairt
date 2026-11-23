# frozen_string_literal: true

module Fotheidil
  # Uploads a recording's audio to the Abair API as a new transcription job and
  # returns the job id. Every call is a fresh submission: the file name is made
  # unique each time, because the API rejects a name it already holds.
  #
  # Video is cut down to its audio first (timestamps are kept 1:1); a recording
  # with a downsampled audio_track uploads that instead of the full media.
  # Nothing on the recording is changed.
  #
  #   Fotheidil::MediaSubmissionService.new(voice_recording).call # => "1234"
  class MediaSubmissionService
    EXTENSIONS = {
      %r{audio/(mpeg|mp3)} => "mp3",
      %r{video/mp4} => "mp4",
      %r{audio/wav} => "wav"
    }.freeze

    def initialize(voice_recording, api: Fotheidil::ApiService.new)
      @voice_recording = voice_recording
      @api = api
    end

    def call
      Dir.mktmpdir("fotheidil") do |dir|
        upload_path = prepare_upload(dir)
        job_id = @api.submit(upload_path, file_name: unique_file_name(upload_path))
        Rails.logger.info "Submitted VoiceRecording##{@voice_recording.id} to Fotheidil as job #{job_id}"
        job_id.to_s
      end
    end

    private

    def blob
      @voice_recording.media.blob
    end

    def prepare_upload(dir)
      return download(@voice_recording.audio_track, File.join(dir, "#{safe_base}_track.mp3")) if use_audio_track?

      media_path = download(@voice_recording.media, File.join(dir, "#{safe_base}.#{extension}"))
      blob.content_type.start_with?("video/") ? extract_audio(media_path, dir) : media_path
    end

    def use_audio_track?
      !blob.content_type.start_with?("video/") && @voice_recording.audio_track.attached?
    end

    def download(attachment, path)
      File.open(path, "wb") { |file| attachment.download { |chunk| file.write(chunk) } }
      path
    end

    # Falls back to the original file if ffmpeg can't extract the audio.
    def extract_audio(video_path, dir)
      audio_path = File.join(dir, "#{safe_base}.mp3")
      system("ffmpeg", "-i", video_path, "-vn", "-acodec", "libmp3lame", "-q:a", "2", "-y", audio_path, err: File::NULL)
      return audio_path if File.size?(audio_path)

      Rails.logger.warn "Audio extraction failed for VoiceRecording##{@voice_recording.id}, uploading the video"
      video_path
    end

    def extension
      blob.filename.extension.presence ||
        EXTENSIONS.find { |pattern, _| blob.content_type.to_s.match?(pattern) }&.last ||
        "mp3"
    end

    def safe_base
      @safe_base ||= (blob.filename.base.presence || @voice_recording.name.to_s)
        .gsub(/[:\/\\]/, "_")
        .gsub(/[^\w\s\-_.]/, "")
        .strip
        .truncate(200)
    end

    # The API derives its stored media name from file_name and rejects one it
    # already holds, so keep the readable base and make it unique per submission.
    def unique_file_name(upload_path)
      "#{safe_base}-#{SecureRandom.hex(4)}#{File.extname(upload_path)}"
    end
  end
end
