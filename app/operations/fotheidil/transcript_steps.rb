# frozen_string_literal: true

module Fotheidil
  # Steps shared by the operations that wait on a Fotheidil job: poll until the
  # transcript is ready, then keep the well-formed segments. Both read the job
  # id from ctx[:fotheidil_video_id] and set ctx[:error] when they fail.
  module TranscriptSteps
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
  end
end
