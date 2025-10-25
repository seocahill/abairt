# frozen_string_literal: true

require "test_helper"

module Fotheidil
  class ProcessVideoOperationTest < ActiveSupport::TestCase
    setup do
      @owner = users(:one)
      @voice_recording = VoiceRecording.create!(
        owner: @owner,
        source: "fotheidil",
        name: "Séamas Deasaí Béal Easa"
      )
      # Attach a dummy media file
      @voice_recording.media.attach(
        io: File.open(Rails.root.join("test/fixtures/files/deasaigh.mp3")),
        filename: "deasaigh.mp3"
      )
    end

    teardown do
      @voice_recording&.destroy
    end

    test "fails when voice recording is nil" do
      result = ProcessVideoOperation.call(voice_recording: nil)

      assert_not result.success?
      assert_equal "Voice recording is required", result[:error]
    end

    test "fails when voice recording has no media" do
      vr = VoiceRecording.create!(owner: @owner, source: "fotheidil")

      result = ProcessVideoOperation.call(voice_recording: vr)

      assert_not result.success?
      assert_equal "Voice recording must have media attached", result[:error]

      vr.destroy
    end

    test "skips if already completed" do
      @voice_recording.update!(
        segments: [{"id" => "1", "text" => "test", "speaker" => "S1", "startTimeSeconds" => 0, "endTimeSeconds" => 1}]
      )
      DictionaryEntry.create!(
        voice_recording: @voice_recording,
        owner: @owner,
        speaker: @owner,
        region_start: 0,
        region_end: 1,
        word_or_phrase: "test"
      )

      result = ProcessVideoOperation.call(voice_recording: @voice_recording)

      assert_not result.success?
      assert_equal "Already completed", result[:error]
    end

    test "successfully uploads and processes new video" do
      # Mock browser service
      browser_service = mock("browser_service")
      browser_service.stubs(:setup_browser).returns(true)
      browser_service.stubs(:authenticate).returns(true)
      browser_service.stubs(:cleanup)

      # Mock upload service
      upload_service = mock("upload_service")
      upload_service.stubs(:upload_file).returns("https://fotheidil.abair.ie/videos/9999")

      # Mock parser service
      parser_service = mock("parser_service")
      segments = [
        {"id" => "0001", "text" => "Uploaded test", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5}
      ]
      parser_service.stubs(:parse_segments).returns(segments)

      # Mock create entries service
      create_speaker_entries_service = mock("create_speaker_entries_service")
      create_speaker_entries_service.stubs(:call)

      Fotheidil::BrowserService.stubs(:new).returns(browser_service)
      Fotheidil::UploadService.stubs(:new).returns(upload_service)
      Fotheidil::ParserService.stubs(:new).returns(parser_service)
      Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

      # Mock wait and post-process steps
      ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(true)
      ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
      ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
      ProcessVideoOperation.any_instance.stubs(:post_process_entries).returns(true)
      ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

      # Call without video_id to trigger upload
      result = ProcessVideoOperation.call(voice_recording: @voice_recording)

      assert result.success?, "Operation should succeed. Error: #{result[:error]}"
      assert_equal "9999", @voice_recording.reload.fotheidil_video_id
      assert_equal 1, @voice_recording.segments.count
    end

    test "successfully processes with existing video_id" do
      # Mock all external services
      browser_service = mock("browser_service")
      browser_service.stubs(:setup_browser).returns(true)
      browser_service.stubs(:authenticate).returns(true)
      browser_service.stubs(:cleanup)

      parser_service = mock("parser_service")
      segments = [
        {"id" => "0001", "text" => "Test 1", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5},
        {"id" => "0002", "text" => "Test 2", "speaker" => "SPEAKER_01", "startTimeSeconds" => 3.0, "endTimeSeconds" => 5.0}
      ]
      parser_service.stubs(:parse_segments).returns(segments)

      create_speaker_entries_service = mock("create_speaker_entries_service")
      create_speaker_entries_service.stubs(:call)

      Fotheidil::BrowserService.stubs(:new).returns(browser_service)
      Fotheidil::ParserService.stubs(:new).returns(parser_service)
      Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

      # Mock the wait and post-process steps
      ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(true)
      ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
      ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
      ProcessVideoOperation.any_instance.stubs(:post_process_entries).returns(true)
      ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

      result = ProcessVideoOperation.call(
        voice_recording: @voice_recording,
        fotheidil_video_id: "1141"
      )

      assert result.success?, "Operation should succeed. Error: #{result[:error]}"
      assert_equal "1141", @voice_recording.reload.fotheidil_video_id
      assert_equal 2, @voice_recording.segments.count
      assert_equal "processing", @voice_recording.diarization_status
    end

    test "marks as failed on authentication error" do
      browser_service = mock("browser_service")
      browser_service.stubs(:setup_browser).returns(false)
      browser_service.stubs(:cleanup)

      Fotheidil::BrowserService.stubs(:new).returns(browser_service)

      result = ProcessVideoOperation.call(
        voice_recording: @voice_recording,
        fotheidil_video_id: "1141"
      )

      assert_not result.success?
      assert_equal "Fotheidil authentication failed", result[:error]
      assert_equal "failed", @voice_recording.reload.diarization_status
    end

    test "marks as failed on parse error" do
      browser_service = mock("browser_service")
      browser_service.stubs(:setup_browser).returns(true)
      browser_service.stubs(:authenticate).returns(true)
      browser_service.stubs(:cleanup)

      parser_service = mock("parser_service")
      parser_service.stubs(:parse_segments).raises(StandardError, "Parse failed")

      Fotheidil::BrowserService.stubs(:new).returns(browser_service)
      Fotheidil::ParserService.stubs(:new).returns(parser_service)

      # Mock wait_for_transcription to succeed
      ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(true)

      result = ProcessVideoOperation.call(
        voice_recording: @voice_recording,
        fotheidil_video_id: "1141"
      )

      assert_not result.success?
      assert_includes result[:error], "Parse failed"
      assert_equal "failed", @voice_recording.reload.diarization_status
    end
  end
end
