# frozen_string_literal: true

require "test_helper"

class TranscodeAudioTrackJobTest < ActiveJob::TestCase
  setup do
    @owner = users(:one)
    @voice_recording = VoiceRecording.create!(owner: @owner, source: "fotheidil", name: "Test")
    @voice_recording.media.attach(
      io: File.open(Rails.root.join("test/fixtures/files/deasaigh.mp3")),
      filename: "deasaigh.mp3",
      content_type: "audio/mpeg"
    )
  end

  teardown do
    @voice_recording&.destroy
  end

  test "skips if audio_track already attached" do
    @voice_recording.audio_track.attach(
      io: File.open(Rails.root.join("test/fixtures/files/deasaigh.mp3")),
      filename: "deasaigh.mp3",
      content_type: "audio/mpeg"
    )
    original_blob_id = @voice_recording.audio_track.blob.id

    TranscodeAudioTrackJob.perform_now(@voice_recording)

    assert_equal original_blob_id, @voice_recording.reload.audio_track.blob.id
  end

  test "skips if media is not audio/mpeg" do
    vr = VoiceRecording.create!(owner: @owner, source: "fotheidil", name: "WAV Test")
    vr.media.attach(io: StringIO.new("dummy"), filename: "test.wav", content_type: "audio/wav")

    TranscodeAudioTrackJob.perform_now(vr)

    refute vr.reload.audio_track.attached?
  ensure
    vr&.destroy
  end

  test "attaches downsampled audio_track" do
    refute @voice_recording.audio_track.attached?

    TranscodeAudioTrackJob.perform_now(@voice_recording)

    assert @voice_recording.reload.audio_track.attached?
    assert_equal "audio/mpeg", @voice_recording.audio_track.content_type
  end

  test "does not attach audio_track if ffmpeg fails" do
    TranscodeAudioTrackJob.any_instance.stubs(:system).returns(false)

    TranscodeAudioTrackJob.perform_now(@voice_recording)

    refute @voice_recording.reload.audio_track.attached?
  end
end
