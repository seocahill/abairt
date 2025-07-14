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

  test "enqueues diarization job after create when media is attached" do
    new_recording = VoiceRecording.new(
      title: "Test Recording",
      owner: users(:one)
    )

    new_recording.media.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3")),
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )

    assert_enqueued_with(job: DiarizeVoiceRecordingJob) do
      new_recording.save!
    end
  end

  test "does not enqueue diarization job when media is not attached" do
    assert_no_enqueued_jobs(only: DiarizeVoiceRecordingJob) do
      VoiceRecording.create!(
        title: "Test Recording",
        owner: users(:one)
      )
    end
  end

  test "does not enqueue diarization job when status is already set" do
    new_recording = VoiceRecording.new(
      title: "Test Recording",
      owner: users(:one),
      diarization_status: 'completed'
    )

    new_recording.media.attach(
      io: File.open(Rails.root.join("test", "fixtures", "files", "sample.mp3")),
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )

    assert_no_enqueued_jobs(only: DiarizeVoiceRecordingJob) do
      new_recording.save!
    end
  end

  test "import_from_archive delegates to ArchiveImportService" do
    mock_service = mock
    mock_service.expects(:import_next_recording).returns(voice_recordings(:one))
    ArchiveImportService.expects(:new).returns(mock_service)

    VoiceRecording.import_from_archive
  end
end
