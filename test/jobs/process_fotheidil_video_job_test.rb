# frozen_string_literal: true

require "test_helper"

class ProcessFotheidilVideoJobTest < ActiveJob::TestCase
  setup do
    @voice_recording = VoiceRecording.create!(
      owner: users(:one),
      title: "Test Recording",
      description: "Test",
      source: "fotheidil",
      fotheidil_video_id: "1141"
    )
    @voice_recording.media.attach(
      io: File.open(Rails.root.join("test/fixtures/files/deasaigh.mp3")),
      filename: "deasaigh.mp3"
    )
  end

  test "calls ProcessVideoOperation with correct params" do
    # Mock the operation
    Fotheidil::ProcessVideoOperation.expects(:call).with(
      voice_recording: @voice_recording,
      fotheidil_video_id: "1141"
    ).returns(
      Struct.new(:success?).new(true)
    )

    ProcessFotheidilVideoJob.perform_now(@voice_recording.id, "1141")
  end

  test "handles operation failure gracefully" do
    # Mock operation to fail
    result = mock("result")
    result.stubs(:success?).returns(false)
    result.stubs(:[]).with(:error).returns("Test error")

    Fotheidil::ProcessVideoOperation.stubs(:call).returns(result)

    assert_nothing_raised do
      ProcessFotheidilVideoJob.perform_now(@voice_recording.id, "1141")
    end
  end
end
