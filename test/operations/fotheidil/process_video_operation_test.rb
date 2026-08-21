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

      # Stub duration calculation - it shells out to ffprobe, which isn't available
      # in CI (returns nil there and previously crashed the operation).
      VoiceRecording.any_instance.stubs(:calculate_duration).returns(120.0)
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

    test "prepare_audio_track creates audio_track for mp3 media" do
      refute @voice_recording.audio_track.attached?

      # Stop pipeline after prepare_audio_track by failing authenticate
      ProcessVideoOperation.any_instance.stubs(:determine_video_source).returns(false)

      ProcessVideoOperation.call(voice_recording: @voice_recording)

      assert @voice_recording.reload.audio_track.attached?
    end

    test "prepare_audio_track skips if audio_track already attached" do
      @voice_recording.audio_track.attach(
        io: File.open(Rails.root.join("test/fixtures/files/deasaigh.mp3")),
        filename: "deasaigh.mp3",
        content_type: "audio/mpeg"
      )
      original_blob_id = @voice_recording.audio_track.blob.id

      ProcessVideoOperation.any_instance.stubs(:determine_video_source).returns(false)

      ProcessVideoOperation.call(voice_recording: @voice_recording)

      assert_equal original_blob_id, @voice_recording.reload.audio_track.blob.id
    end

    test "prepare_audio_track skips for non-mp3 media" do
      @voice_recording.media.attach(
        io: StringIO.new("dummy"),
        filename: "test.wav",
        content_type: "audio/wav"
      )

      ProcessVideoOperation.any_instance.stubs(:determine_video_source).returns(false)

      ProcessVideoOperation.call(voice_recording: @voice_recording)

      refute @voice_recording.reload.audio_track.attached?
    end

    test "prepare_audio_track fails and marks recording failed if ffmpeg fails" do
      ProcessVideoOperation.any_instance.stubs(:system).returns(false)

      result = ProcessVideoOperation.call(voice_recording: @voice_recording)

      assert_not result.success?
      assert_includes result[:error], "downsampling failed"
      assert_equal "failed", @voice_recording.reload.diarization_status
    end

    test "successfully submits and processes new media" do
      ProcessVideoOperation.any_instance.stubs(:prepare_audio_track).returns(true)

      segments = [
        {"id" => "0001", "text" => "Uploaded test", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5}
      ]

      api_service = mock("api_service")
      api_service.stubs(:submit).returns(9999)
      api_service.stubs(:transcript).returns(segments)

      create_speaker_entries_service = mock("create_speaker_entries_service")
      create_speaker_entries_service.stubs(:call)

      Fotheidil::ApiService.stubs(:new).returns(api_service)
      Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

      # Mock wait and post-process steps
      ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
      ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
      ProcessVideoOperation.any_instance.stubs(:post_process_entries).returns(true)
      ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

      # Call without video_id to trigger submission
      result = ProcessVideoOperation.call(voice_recording: @voice_recording)

      assert result.success?, "Operation should succeed. Error: #{result[:error]}"
      assert_equal "9999", @voice_recording.reload.fotheidil_video_id
      assert_equal 1, @voice_recording.segments.count
    end

    test "submits a unique file name so the api does not reject a duplicate" do
      ProcessVideoOperation.any_instance.stubs(:prepare_audio_track).returns(true)

      api_service = mock("api_service")
      api_service.expects(:submit).with do |_path, file_name:|
        file_name.start_with?("deasaigh-") && file_name.end_with?(".mp3")
      end.returns(9999)
      Fotheidil::ApiService.stubs(:new).returns(api_service)

      # Halt once the submission has happened
      ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(false)

      ProcessVideoOperation.call(voice_recording: @voice_recording)
    end

    test "successfully processes with existing video_id" do
      ProcessVideoOperation.any_instance.stubs(:prepare_audio_track).returns(true)

      segments = [
        {"id" => "0001", "text" => "Test 1", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5},
        {"id" => "0002", "text" => "Test 2", "speaker" => "SPEAKER_01", "startTimeSeconds" => 3.0, "endTimeSeconds" => 5.0}
      ]

      api_service = mock("api_service")
      api_service.stubs(:transcript).returns(segments)

      create_speaker_entries_service = mock("create_speaker_entries_service")
      create_speaker_entries_service.stubs(:call)

      Fotheidil::ApiService.stubs(:new).returns(api_service)
      Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

      # Mock the wait and post-process steps
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

    test "marks as failed when the api rejects the key" do
      ProcessVideoOperation.any_instance.stubs(:prepare_audio_track).returns(true)

      api_service = mock("api_service")
      api_service.stubs(:transcript).raises(Fotheidil::ApiService::Error, "Abair API 401: Unauthorized")
      Fotheidil::ApiService.stubs(:new).returns(api_service)

      result = ProcessVideoOperation.call(
        voice_recording: @voice_recording,
        fotheidil_video_id: "1141"
      )

      assert_not result.success?
      assert_includes result[:error], "401"
      assert_equal "failed", @voice_recording.reload.diarization_status
    end

    test "marks as failed when the transcription comes back empty" do
      ProcessVideoOperation.any_instance.stubs(:prepare_audio_track).returns(true)

      api_service = mock("api_service")
      api_service.stubs(:transcript).returns([])
      Fotheidil::ApiService.stubs(:new).returns(api_service)

      result = ProcessVideoOperation.call(
        voice_recording: @voice_recording,
        fotheidil_video_id: "1141"
      )

      assert_not result.success?
      assert_equal "No segments found", result[:error]
      assert_equal "failed", @voice_recording.reload.diarization_status
    end

    test "drops segments that are missing timings" do
      ProcessVideoOperation.any_instance.stubs(:prepare_audio_track).returns(true)

      api_service = mock("api_service")
      api_service.stubs(:transcript).returns([
        {"id" => "0001", "text" => "Good", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5},
        {"id" => "0002", "text" => "No timings", "speaker" => "SPEAKER_00"}
      ])
      Fotheidil::ApiService.stubs(:new).returns(api_service)

      create_speaker_entries_service = mock("create_speaker_entries_service")
      create_speaker_entries_service.stubs(:call)
      Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

      ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
      ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
      ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

      ProcessVideoOperation.call(
        voice_recording: @voice_recording,
        fotheidil_video_id: "1141"
      )

      assert_equal 1, @voice_recording.reload.segments.count
    end
  end
end
