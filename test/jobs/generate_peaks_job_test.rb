require "test_helper"

class GeneratePeaksJobTest < ActiveJob::TestCase
  test "that peaks are generated" do
    assert voice_recordings(:one).media.attached?
    GeneratePeaksJob.perform_now(voice_recordings(:one).id)
    assert voice_recordings(:one).reload.peaks.length > 1
  end
end
