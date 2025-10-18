require "test_helper"

class VoiceRecordingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @voice_recording = voice_recordings(:one)
  end

  test "voice recording enqueues peaks job when media attached" do
    @voice_recording.update!(peaks: nil)  # Ensure peaks are blank

    assert_no_enqueued_jobs(only: GeneratePeaksJob) do
      @voice_recording.media.attach(
        io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3")),
        filename: "sample.mp3",
        content_type: "audio/mpeg"
      )
      @voice_recording.save!
    end
  end

  # Job enqueueing is now handled explicitly in the controller, not via callbacks
  # See VoiceRecordingsController#create and test/controllers/voice_recordings_controller_test.rb

  test "import_from_archive delegates to ArchiveImportService" do
    mock_service = mock
    mock_service.expects(:import_next_recording).returns(voice_recordings(:one))
    ArchiveImportService.expects(:new).returns(mock_service)

    VoiceRecording.import_from_archive
  end
end
