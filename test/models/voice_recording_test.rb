require "test_helper"

class VoiceRecordingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "voice recording" do
    assert_enqueued_with(job: GeneratePeaksJob) do
      voice_recordings(:two).media.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3")),
        filename: "sample.mp3",
        content_type: "audio/mpeg"
      )
    end
  end
end
