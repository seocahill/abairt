# frozen_string_literal: true

module Fotheidil
  class SegmentUploadChecker
    # Conservative estimate: ~10 second segments
    AVERAGE_SEGMENT_DURATION = 10

    # Allow 5 second gap at end for silence
    END_TIME_TOLERANCE = 5

    def initialize(voice_recording)
      @voice_recording = voice_recording
      @duration = voice_recording.duration_seconds || 0
      @segments = voice_recording.segments || []
    end

    def complete?
      duration_available? && segments_present? && has_minimum_segment_count? && last_segment_near_end?
    end

    def status_message
      return "Duration not available" unless duration_available?
      return "No segments found" unless segments_present?
      return "Insufficient segments (#{segments_count}/#{expected_min_segments})" unless has_minimum_segment_count?
      return "Last segment ends too early (#{last_segment_end_time}s/#{@duration}s)" unless last_segment_near_end?

      "All segments uploaded"
    end

    private

    def duration_available?
      @duration&.positive?
    end

    def segments_present?
      @segments.is_a?(Array) && @segments.any?
    end

    def segments_count
      @segments.length
    end

    def has_minimum_segment_count?
      segments_count >= expected_min_segments
    end

    def expected_min_segments
      return 0 unless duration_available?
      (@duration / AVERAGE_SEGMENT_DURATION).floor
    end

    def last_segment_near_end?
      return false unless last_segment_end_time

      last_segment_end_time >= (@duration - END_TIME_TOLERANCE)
    end

    def last_segment_end_time
      @last_segment_end_time ||= @segments.last&.dig("endTimeSeconds")
    end
  end
end
