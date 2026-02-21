require "test_helper"

class TranscriptAnalysisJobTest < ActiveJob::TestCase
  test "performs transcript analysis for the last voice recording" do
    recording = voice_recordings(:one)
    TranscriptAnalysisService.expects(:new).with(recording).returns(
      Struct.new(:analyze).new(true)
    )
    TranscriptAnalysisJob.perform_now
  end
end
