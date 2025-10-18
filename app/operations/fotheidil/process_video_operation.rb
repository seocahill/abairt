# frozen_string_literal: true

module Fotheidil
  # Trailblazer operation for processing Fotheidil videos
  # Handles authentication, upload/fetch, parsing, entry creation, and publishing
  #
  # Usage:
  #   result = Fotheidil::ProcessVideoOperation.call(
  #     voice_recording: voice_recording,
  #     fotheidil_video_id: "1141" # Optional: use existing video
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
    step :authenticate
    step :determine_video_source
    step :parse_segments
    step :save_segments
    step :calculate_duration
    step :wait_for_segments
    step :create_entries
    step :wait_for_entries
    step :post_process_entries
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

      completed = voice_recording.dictionary_entries_count >= voice_recording.segments.count

      if completed
        Rails.logger.info "VoiceRecording #{voice_recording.id} already completed"
        ctx[:error] = "Already completed"
      end

      !completed
    end

    # Authenticate with Fotheidil
    def authenticate(ctx, **)
      Rails.logger.info "Authenticating with Fotheidil..."

      email = Rails.application.credentials.dig(:fotheidil, :email)
      password = Rails.application.credentials.dig(:fotheidil, :password)

      browser_service = Fotheidil::BrowserService.new(email, password)

      unless browser_service.setup_browser && browser_service.authenticate
        ctx[:error] = "Fotheidil authentication failed"
        return false
      end

      ctx[:browser_service] = browser_service
      Rails.logger.info "Fotheidil authentication successful"
      true
    end

    # Determine video source: use existing ID or upload new video
    def determine_video_source(ctx, voice_recording:, browser_service:, fotheidil_video_id: nil, **)
      if fotheidil_video_id.present?
        Rails.logger.info "Using existing Fotheidil video ID: #{fotheidil_video_id}"
        ctx[:fotheidil_video_id] = fotheidil_video_id
        return true
      end

      # Upload new video
      upload_and_extract_id(ctx, voice_recording, browser_service)
    end

    # Upload video and extract ID
    def upload_and_extract_id(ctx, voice_recording, browser_service)
      Rails.logger.info "Uploading new video to Fotheidil..."

      # Download media to temp file
      temp_path = "/tmp/voice_recording_#{voice_recording.id}#{File.extname(voice_recording.media.filename.to_s)}"

      File.open(temp_path, "wb") do |file|
        voice_recording.media.download do |chunk|
          file.write(chunk)
        end
      end

      # Upload to Fotheidil
      upload_service = Fotheidil::UploadService.new(browser_service)
      video_url = upload_service.upload_file(temp_path)

      if video_url.blank?
        ctx[:error] = "Upload failed - no video URL returned"
        return false
      end

      # Extract video ID from URL
      match = video_url.match(%r{/videos/(\d+)})

      if match
        ctx[:fotheidil_video_id] = match[1]
        Rails.logger.info "Upload successful - video ID: #{match[1]}"
        true
      else
        ctx[:error] = "Failed to extract video ID from URL: #{video_url}"
        false
      end
    rescue => e
      ctx[:error] = "Upload error: #{e.message}"
      Rails.logger.error "Upload error: #{e.message}"
      false
    ensure
      File.delete(temp_path) if temp_path && File.exist?(temp_path)
    end

    # Parse segments from Fotheidil
    def parse_segments(ctx, browser_service:, **)
      fotheidil_video_id = ctx[:fotheidil_video_id]

      unless fotheidil_video_id
        ctx[:error] = "No fotheidil_video_id available"
        return false
      end

      Rails.logger.info "Parsing segments for video #{fotheidil_video_id}..."

      # Clean up the upload browser session before creating a new one for parsing
      browser_service&.cleanup
      Rails.logger.info "Cleaned up upload browser session"

      parser_service = Fotheidil::ParserService.new
      segments = parser_service.parse_segments(fotheidil_video_id)

      if segments.blank?
        ctx[:error] = "No segments found"
        return false
      end

      ctx[:segments] = segments
      Rails.logger.info "Parsed #{segments.length} segments"
      true
    rescue => e
      ctx[:error] = "Failed to parse segments: #{e.message}"
      Rails.logger.error "Parse error: #{e.message}"
      false
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
          ctx[:error] = "Timeout waiting for segments: #{checker.status_message}"
          Rails.logger.error ctx[:error]
          return false
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
      segments = ctx[:segments]
      Rails.logger.info "Waiting for dictionary entries to be created (timeout: #{timeout}s)..."

      expected_count = segments.count
      start_time = Time.current

      loop do
        voice_recording.reload
        current_count = voice_recording.dictionary_entries_count

        if current_count >= expected_count
          Rails.logger.info "All #{expected_count} dictionary entries created"
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

    # Post-process all entries (translation, tagging, audio snippets)
    def post_process_entries(ctx, voice_recording:, **)
      Rails.logger.info "Post-processing dictionary entries..."

      voice_recording.dictionary_entries.find_each do |entry|
        entry.post_process
      end

      Rails.logger.info "Queued post-processing for #{voice_recording.dictionary_entries_count} entries"
      true
    rescue => e
      ctx[:error] = "Failed to post-process entries: #{e.message}"
      Rails.logger.error "Post-process error: #{e.message}"
      false
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

    # Cleanup browser after operation
    def cleanup(ctx, browser_service: nil, **)
      browser_service&.cleanup
    end
  end
end
