# frozen_string_literal: true

require "test_helper"

module Fotheidil
  class SegmentUploadCheckerTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @voice_recording = VoiceRecording.create!(
        title: "Test Recording",
        owner: @user,
        duration_seconds: 100
      )

      # Load real fixture data
      @fixture_html = Rails.root.join("test/fixtures/files/fotheidil_video_1141.html").read
      @parser = ParserService.new
      @real_segments = @parser.parse_html(@fixture_html)
    end

    test "complete? returns false when duration is zero" do
      @voice_recording.update!(duration_seconds: 0)
      checker = SegmentUploadChecker.new(@voice_recording)

      assert_not checker.complete?
      assert_equal "Duration not available", checker.status_message
    end

    test "complete? returns false when no segments present" do
      @voice_recording.update!(segments: [])
      checker = SegmentUploadChecker.new(@voice_recording)

      assert_not checker.complete?
      assert_equal "No segments found", checker.status_message
    end

    test "complete? returns false when insufficient segment count" do
      # 100 second duration should expect ~10 segments (100/10)
      # Give it only 5 segments
      segments = [
        {"startTimeSeconds" => 0, "endTimeSeconds" => 20},
        {"startTimeSeconds" => 20, "endTimeSeconds" => 40},
        {"startTimeSeconds" => 40, "endTimeSeconds" => 60},
        {"startTimeSeconds" => 60, "endTimeSeconds" => 80},
        {"startTimeSeconds" => 80, "endTimeSeconds" => 95}
      ]
      @voice_recording.update!(segments: segments)
      checker = SegmentUploadChecker.new(@voice_recording)

      assert_not checker.complete?
      assert_match(/Insufficient segments/, checker.status_message)
    end

    test "complete? returns false when last segment ends too early" do
      # Last segment ends at 85s, but duration is 100s (15s gap > 5s tolerance)
      segments = Array.new(10) do |i|
        start = i * 8.5
        {
          "startTimeSeconds" => start,
          "endTimeSeconds" => start + 8.5
        }
      end
      @voice_recording.update!(segments: segments)
      checker = SegmentUploadChecker.new(@voice_recording)

      assert_not checker.complete?
      assert_match(/Last segment ends too early/, checker.status_message)
    end

    test "complete? returns true when all checks pass" do
      # 100 second duration with 10 segments, last ending at 98s (within tolerance)
      segments = Array.new(10) do |i|
        start = i * 9.8
        {
          "startTimeSeconds" => start,
          "endTimeSeconds" => start + 9.8
        }
      end
      @voice_recording.update!(segments: segments)
      checker = SegmentUploadChecker.new(@voice_recording)

      assert checker.complete?
      assert_equal "All segments uploaded", checker.status_message
    end

    test "handles edge case with exactly 5 second tolerance" do
      # Last segment ends at exactly 95s (100 - 5)
      segments = Array.new(10) do |i|
        start = i * 9.5
        {
          "startTimeSeconds" => start,
          "endTimeSeconds" => start + 9.5
        }
      end
      @voice_recording.update!(segments: segments)
      checker = SegmentUploadChecker.new(@voice_recording)

      assert checker.complete?
      assert_equal "All segments uploaded", checker.status_message
    end

    test "handles voice recording with no segments field" do
      @voice_recording.update!(segments: nil)
      checker = SegmentUploadChecker.new(@voice_recording)

      assert_not checker.complete?
      assert_equal "No segments found", checker.status_message
    end

    test "validates with real fixture data from video 1141" do
      # Real data: 395 segments, last segment ends at 1478.77s (~24:39)
      last_segment = @real_segments.last
      duration = last_segment["endTimeSeconds"]

      @voice_recording.update!(
        duration_seconds: duration,
        segments: @real_segments
      )
      checker = SegmentUploadChecker.new(@voice_recording)

      assert_equal 395, @real_segments.length, "Expected 395 segments from fixture"
      assert_equal 1478.77, duration, "Expected last segment to end at 1478.77s"
      assert checker.complete?, "Should be complete with all real segments"
      assert_equal "All segments uploaded", checker.status_message
    end

    test "detects incomplete upload with real fixture missing last segments" do
      # Simulate incomplete upload - only first 200 segments uploaded
      # Duration still shows full video length, but segments are missing
      incomplete_segments = @real_segments.first(200)
      full_duration = @real_segments.last["endTimeSeconds"]

      @voice_recording.update!(
        duration_seconds: full_duration,
        segments: incomplete_segments
      )
      checker = SegmentUploadChecker.new(@voice_recording)

      assert_not checker.complete?
      # Should fail on insufficient count (200 < 147 expected from 1478/10)
      # or last segment ending too early (200th segment ends much earlier than 1478)
      assert_match(/(Insufficient segments|Last segment ends too early)/, checker.status_message)
    end
  end
end
