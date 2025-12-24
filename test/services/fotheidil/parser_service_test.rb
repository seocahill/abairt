# frozen_string_literal: true

require "test_helper"

module Fotheidil
  class ParserServiceTest < ActiveSupport::TestCase
    def setup
      @fixture_html = Rails.root.join("test/fixtures/files/fotheidil_video_1141.html").read
    end

    test "parses segments from HTML" do
      parser = ParserService.new
      segments = parser.parse_html(@fixture_html)

      assert segments.is_a?(Array)
      assert segments.length > 0
    end

    test "extracts speaker from segment" do
      parser = ParserService.new
      segments = parser.parse_html(@fixture_html)

      first_segment = segments.first

      assert_equal "SPEAKER_00", first_segment["speaker"]
    end

    test "extracts start time from segment" do
      parser = ParserService.new
      segments = parser.parse_html(@fixture_html)

      first_segment = segments.first

      assert_equal 0.03, first_segment["startTimeSeconds"]
    end

    test "extracts end time from segment" do
      parser = ParserService.new
      segments = parser.parse_html(@fixture_html)

      first_segment = segments.first

      assert_equal 14.16, first_segment["endTimeSeconds"]
    end

    test "extracts text from segment" do
      parser = ParserService.new
      segments = parser.parse_html(@fixture_html)

      first_segment = segments.first

      assert first_segment["text"].include?("Anois bhí an lá")
    end

    test "handles multiple speakers" do
      parser = ParserService.new
      segments = parser.parse_html(@fixture_html)

      # Check that we have segments with different speakers
      speakers = segments.map { |s| s["speaker"] }.uniq

      assert_includes speakers, "SPEAKER_00"
      assert_includes speakers, "SPEAKER_01"
    end

    test "extracts all segments from page" do
      parser = ParserService.new
      segments = parser.parse_html(@fixture_html)

      # The first page should have multiple segments
      assert segments.length >= 10
    end

    test "parses segments from script tag using fixture" do
      parser = ParserService.new

      # Stub get_page_source to return our fixture using mocha
      parser.stubs(:get_page_source).with(1141).returns(@fixture_html)

      segments = parser.parse_segments(1141)

      # Fixture contains all 395 segments from video 1141
      assert_equal 395, segments.length

      # Verify first segment structure (JSON returns string keys)
      first = segments.first
      assert_equal "SPEAKER_00", first["speaker"]
      assert_equal 0.03, first["startTimeSeconds"]
      assert_equal 14.16, first["endTimeSeconds"]
      assert first["text"].include?("Anois bhí an lá")

      # Verify all segments have required fields
      segments.each do |segment|
        assert segment["speaker"].present?
        assert segment["startTimeSeconds"].present?
        assert segment["endTimeSeconds"].present?
        assert segment["text"].present?
      end
    end
  end
end
