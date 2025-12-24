# frozen_string_literal: true

require "test_helper"

module Fotheidil
  class CreateSpeakerEntriesServiceTest < ActiveJob::TestCase
    def setup
      @owner = users(:one)
      @voice_recording = VoiceRecording.create!(
        owner: @owner,
        source: "fotheidil",
        segments: []
      )
    end

    test "normalizes Fotheidil segment format to ProcessDiarizationSegmentJob format" do
      # Fotheidil format from parser
      fotheidil_segment = {
        "id" => "0000",
        "text" => "Test phrase",
        "speaker" => "SPEAKER_00",
        "startTimeSeconds" => 0.5,
        "endTimeSeconds" => 2.5
      }

      service = CreateSpeakerEntriesService.new(@voice_recording)
      normalized = service.send(:normalize_segment, fotheidil_segment)

      # Should transform to ProcessDiarizationSegmentJob format
      assert_equal 0.5, normalized["start"]
      assert_equal 2.5, normalized["end"]
      assert_equal "Test phrase", normalized["text"]
      assert_equal "SPEAKER_00", normalized["speaker"]
      assert_nil normalized["errors"]
    end

    test "adds errors for invalid segments" do
      invalid_segment = {
        "id" => "0001",
        "speaker" => "SPEAKER_00",
        "startTimeSeconds" => 5.0,
        "endTimeSeconds" => 2.5  # End before start
      }

      service = CreateSpeakerEntriesService.new(@voice_recording)
      normalized = service.send(:normalize_segment, invalid_segment)

      assert_includes normalized["errors"], "Missing text"
      assert_includes normalized["errors"], "Start time must be less than end time"
    end

    test "skips invalid segments when queueing jobs" do
      @voice_recording.update!(
        segments: [
          {
            "id" => "0001",
            "text" => "Valid segment",
            "speaker" => "SPEAKER_00",
            "startTimeSeconds" => 0.5,
            "endTimeSeconds" => 2.5
          },
          {
            "id" => "0002",
            "speaker" => "SPEAKER_00",
            "startTimeSeconds" => 3.0
            # Missing endTimeSeconds and text - invalid
          }
        ]
      )

      service = CreateSpeakerEntriesService.new(@voice_recording)

      # Should only queue 1 valid segment (invalid one logged and skipped)
      assert_enqueued_jobs 1, only: ProcessDiarizationSegmentJob do
        service.call
      end
    end

    test "processes all valid segments from test fixture" do
      parser = Fotheidil::ParserService.new
      html = File.read(Rails.root.join("test/fixtures/files/fotheidil_video_1141.html"))
      segments = parser.parse_html(html)

      @voice_recording.update!(segments: segments)
      service = CreateSpeakerEntriesService.new(@voice_recording)

      # All segments in fixture should be valid
      assert_enqueued_jobs segments.length, only: ProcessDiarizationSegmentJob do
        service.call
      end
    end
  end
end
