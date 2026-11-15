require "test_helper"

class RefreshAndroidReleaseJobTest < ActiveJob::TestCase
  test "asks the service to refresh" do
    AndroidRelease.expects(:refresh)

    RefreshAndroidReleaseJob.perform_now
  end
end
