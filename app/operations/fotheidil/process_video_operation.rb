# frozen_string_literal: true

module Fotheidil
  # Trailblazer operation for processing Fotheidil videos
  # Handles submission, transcription, entry creation, and publishing via the
  # Abair API (see Fotheidil::ApiService)
  #
  # Usage:
  #   result = Fotheidil::ProcessVideoOperation.call(
  #     voice_recording: voice_recording,
  #     fotheidil_video_id: "1141" # Optional: use an existing transcription job
  #   )
  #
  #   if result.success?
  #     result[:voice_recording] # Updated voice recording
  #   else
  #     result[:error] # Error message
  #   end
  class ProcessVideoOperation < Trailblazer::Operation
    # Override call to show wtf? output in development
    # def self.call(options = {})
    #   if Rails.env.development?
    #     Trailblazer::Developer.wtf?(self, options)
    #   else
    #     super
    #   end
    # end
    step :validate_voice_recording
    step :check_not_already_completed, Output(:failure) => End(:already_completed)
    step :prepare_audio_track
    step :determine_video_source
    step :wait_for_transcription
    step :parse_segments
    step :save_segments
    step :calculate_duration
    step :wait_for_segments
    step :create_entries
    step :wait_for_entries
    step :publish
    fail :mark_as_failed

    # Validate voice recording exists and has media
    def validate_voice_recording(ctx, voice_recording:, **)
      unless voice_recording
        ctx[:error] = "Voice recording is required"
        return false
      end

      unless voice_recording.media.attached?
        ctx[:error] = "Voice recording must have media attached"
        return false
      end

      ctx[:voice_recording] = voice_recording
      true
    end

    # Check if already completed (skip processing if done)
    def check_not_already_completed(ctx, voice_recording:, **)
      return true if voice_recording.segments.blank?

      if voice_recording.fully_transcribed?
        Rails.logger.info "VoiceRecording #{voice_recording.id} already completed"
        ctx[:error] = "Already completed"
        return false
      end

      true
    end

    # Downsample MP3 media to 128kbps mono 16kHz and store as audio_track.
    # Keeps upload sizes well under the 100MB Fotheidil limit (e.g. 320kbps
    # 47-min file goes from ~113MB to ~27MB). Skipped if already attached.
    def prepare_audio_track(ctx, voice_recording:, **)
      return true if voice_recording.audio_track.attached?
      return true unless voice_recording.media.content_type == "audio/mpeg"

      Rails.logger.info "Preparing audio_track for VoiceRecording##{voice_recording.id}..."

      voice_recording.media.open do |input|
        Tempfile.create(["audio_track", ".mp3"], binmode: true) do |output|
          success = system(
            "ffmpeg", "-i", input.path,
            "-vn",
            "-acodec", "libmp3lame",
            "-b:a", "128k",
            "-ac", "1",
            "-ar", "16000",
            "-y",
            output.path,
            err: File::NULL
          )

          unless success
            ctx[:error] = "Audio downsampling failed for VoiceRecording##{voice_recording.id}"
            return false
          end

          voice_recording.audio_track.attach(
            io: File.open(output.path),
            filename: "#{voice_recording.media.filename.base}_track.mp3",
            content_type: "audio/mpeg"
          )
        end
      end

      Rails.logger.info "audio_track prepared for VoiceRecording##{voice_recording.id}"
      true
    rescue => e
      ctx[:error] = "Audio downsampling error: #{e.message}"
      false
    end

    # Determine video source: use existing ID or submit new media
    def determine_video_source(ctx, voice_recording:, fotheidil_video_id: nil, **)
      if fotheidil_video_id.present?
        Rails.logger.info "Using existing Fotheidil video ID: #{fotheidil_video_id}"
        ctx[:fotheidil_video_id] = fotheidil_video_id
        return true
      end

      submit_media(ctx, voice_recording)
    end

    # Submit media to the Abair API and record the job id
    def submit_media(ctx, voice_recording)
      Rails.logger.info "Uploading new video to Fotheidil..."

      # Use Active Storage's filename methods
      blob = voice_recording.media.blob
      extension = blob.filename.extension.presence

      # If no extension, infer from content type
      unless extension
        extension = case blob.content_type
        when /audio\/mpeg/, /audio\/mp3/
          "mp3"
        when /video\/mp4/
          "mp4"
        when /audio\/wav/
          "wav"
        else
          "mp3" # Default fallback
        end
        Rails.logger.info "Inferred extension .#{extension} from content_type #{blob.content_type}"
      end

      # Use blob filename base, sanitize for filesystem, fallback to voice recording name
      base_name = blob.filename.base.presence || voice_recording.name.to_s
      safe_base = base_name
        .gsub(/[:\/\\]/, "_")  # Replace invalid filesystem chars
        .gsub(/[^\w\s\-_.]/, "")  # Remove other special chars
        .strip
        .truncate(200)  # Limit length

      temp_path = "/tmp/#{safe_base}.#{extension}"
      audio_path = nil
      Rails.logger.info "Creating temp file: #{temp_path}"

      File.open(temp_path, "wb") do |file|
        voice_recording.media.download do |chunk|
          file.write(chunk)
        end
      end

      # Always submit audio - extract from video if needed. Audio timestamps are
      # preserved 1:1 so video playback alignment is unaffected.
      upload_path = if blob.content_type.start_with?("video/")
        audio_path = "/tmp/#{safe_base}.mp3"
        Rails.logger.info "Extracting audio track from video for Fotheidil upload: #{audio_path}"
        system("ffmpeg", "-i", temp_path, "-vn", "-acodec", "libmp3lame", "-q:a", "2", "-y", audio_path)

        if File.exist?(audio_path) && File.size(audio_path) > 0
          Rails.logger.info "Audio extraction successful, uploading audio instead of video"
          audio_path
        else
          Rails.logger.warn "Audio extraction failed, falling back to original file"
          temp_path
        end
      elsif voice_recording.audio_track.attached?
        audio_path = "/tmp/#{safe_base}_track.mp3"
        File.open(audio_path, "wb") do |f|
          voice_recording.audio_track.download { |chunk| f.write(chunk) }
        end
        Rails.logger.info "Using downsampled audio_track for upload: #{audio_path}"
        audio_path
      else
        temp_path
      end

      # The API derives its stored media name from file_name and rejects one it
      # already holds, so keep the readable base and make it unique per submission.
      file_name = "#{safe_base}-#{SecureRandom.hex(4)}#{File.extname(upload_path)}"
      job_id = Fotheidil::ApiService.new.submit(upload_path, file_name: file_name)

      ctx[:fotheidil_video_id] = job_id.to_s
      Rails.logger.info "Submission successful - job ID: #{job_id}"
      true
    rescue => e
      ctx[:error] = "Upload error: #{e.message}"
      Rails.logger.error "Upload error: #{e.message}"
      false
    ensure
      File.delete(temp_path) if temp_path && File.exist?(temp_path)
      File.delete(audio_path) if audio_path && File.exist?(audio_path)
    end

    # Wait for the Abair API to finish transcribing (can take several minutes)
    def wait_for_transcription(ctx, timeout: 1800, interval: 30, **)
      fotheidil_video_id = ctx[:fotheidil_video_id]

      unless fotheidil_video_id
        ctx[:error] = "No fotheidil_video_id available"
        return false
      end

      Rails.logger.info "Waiting for Fotheidil transcription (job #{fotheidil_video_id}, timeout: #{timeout}s)..."

      service = Fotheidil::ApiService.new
      start_time = Time.current

      loop do
        transcript = service.transcript(fotheidil_video_id)

        # nil means recognition is still running; an empty array means it
        # finished with nothing, which parse_segments reports straight away
        unless transcript.nil?
          Rails.logger.info "Transcription ready after #{(Time.current - start_time).round}s"
          ctx[:transcript] = transcript
          return true
        end

        if Time.current - start_time > timeout
          ctx[:error] = "Timeout waiting for transcription to appear on Fotheidil"
          Rails.logger.error ctx[:error]
          return false
        end

        Rails.logger.debug { "Not transcribed yet, checking again in #{interval}s..." }
        sleep interval
      end
    rescue => e
      ctx[:error] = "Error waiting for transcription: #{e.message}"
      Rails.logger.error ctx[:error]
      false
    end

    # Keep only well-formed segments - a segment missing its timings cannot be
    # turned into a dictionary entry downstream
    def parse_segments(ctx, **)
      segments = Array(ctx[:transcript]).select do |segment|
        segment["startTimeSeconds"].present? && segment["endTimeSeconds"].present? && segment["text"].present?
      end

      if segments.blank?
        ctx[:error] = "No segments found"
        return false
      end

      ctx[:segments] = segments
      Rails.logger.info "Parsed #{segments.length} segments"
      true
    end

    # Save segments to voice recording
    def save_segments(ctx, voice_recording:, **)
      segments = ctx[:segments]
      fotheidil_video_id = ctx[:fotheidil_video_id]

      voice_recording.update!(
        segments: segments,
        fotheidil_video_id: fotheidil_video_id,
        diarization_status: "processing"
      )

      Rails.logger.info "Saved #{segments.length} segments to VoiceRecording #{voice_recording.id}"
      true
    rescue => e
      ctx[:error] = "Failed to save segments: #{e.message}"
      false
    end

    # Calculate duration from media file
    def calculate_duration(ctx, voice_recording:, **)
      return true if voice_recording.duration_seconds.present? && voice_recording.duration_seconds.positive?

      Rails.logger.info "Calculating duration for VoiceRecording #{voice_recording.id}..."

      voice_recording.media.open do |file|
        duration = voice_recording.calculate_duration(file.path)

        if duration.present? && duration.positive?
          voice_recording.update!(duration_seconds: duration)
          Rails.logger.info "Duration calculated: #{duration}s"
          true
        else
          ctx[:error] = "Failed to calculate duration"
          false
        end
      end
    rescue => e
      ctx[:error] = "Duration calculation error: #{e.message}"
      Rails.logger.error ctx[:error]
      false
    end

    # Wait for all segments to be uploaded to Fotheidil
    def wait_for_segments(ctx, voice_recording:, timeout: 300, **)
      Rails.logger.info "Waiting for all segments to upload (timeout: #{timeout}s)..."

      start_time = Time.current
      checker = Fotheidil::SegmentUploadChecker.new(voice_recording)

      loop do
        voice_recording.reload
        checker = Fotheidil::SegmentUploadChecker.new(voice_recording)

        if checker.complete?
          Rails.logger.info "All segments uploaded successfully"
          return true
        end

        if Time.current - start_time > timeout
          if voice_recording.segments.present?
            Rails.logger.warn "Timeout waiting for segments: #{checker.status_message} - continuing with partial results"
            return true
          else
            ctx[:error] = "Timeout waiting for segments - no segments found"
            Rails.logger.error ctx[:error]
            return false
          end
        end

        Rails.logger.debug { "Segment upload status: #{checker.status_message}" }
        sleep 5
      end
    end

    # Create dictionary entries from segments
    def create_entries(ctx, voice_recording:, **)
      Rails.logger.info "Creating dictionary entries..."

      Fotheidil::CreateSpeakerEntriesService.new(voice_recording).call

      Rails.logger.info "Queued dictionary entry creation"
      true
    rescue => e
      ctx[:error] = "Failed to create entries: #{e.message}"
      false
    end

    # Wait for entries to be created
    def wait_for_entries(ctx, voice_recording:, timeout: 300, **)
      Rails.logger.info "Waiting for dictionary entries to be created (timeout: #{timeout}s)..."

      start_time = Time.current

      loop do
        voice_recording.reload
        expected_count = voice_recording.expected_entries_count
        current_count = voice_recording.dictionary_entries_count

        if current_count >= expected_count
          Rails.logger.info "All entries created (#{current_count}/#{expected_count})"
          return true
        end

        if Time.current - start_time > timeout
          ctx[:error] = "Timeout waiting for entries (#{current_count}/#{expected_count} completed)"
          Rails.logger.error ctx[:error]
          return false
        end

        Rails.logger.debug { "Dictionary entries: #{current_count}/#{expected_count}" }
        sleep 5
      end
    end

    # Mark as completed
    def publish(ctx, voice_recording:, **)
      voice_recording.update!(diarization_status: "completed", import_status: "completed")
      Rails.logger.info "VoiceRecording #{voice_recording.id} processing completed"
      true
    rescue => e
      ctx[:error] = "Failed to publish: #{e.message}"
      false
    end

    # Mark as failed
    def mark_as_failed(ctx, voice_recording: nil, **)
      error = ctx[:error]
      return true unless voice_recording

      voice_recording.update!(diarization_status: "failed")
      Rails.logger.error "Fotheidil processing failed for VoiceRecording #{voice_recording.id}: #{error}"
      true
    end
  end
end
