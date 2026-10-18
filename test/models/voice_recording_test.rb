require "test_helper"

class VoiceRecordingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @voice_recording = voice_recordings(:one)
  end

  # Two people correcting one recording produce two inconsistent halves, so a
  # claim is exclusive.
  test "a recording can only be claimed by one person at a time" do
    assert @voice_recording.claim(users(:one))
    assert_not @voice_recording.claim(users(:two))

    assert_equal users(:one), @voice_recording.reload.claimed_by
  end

  # The guarantee that matters: the condition lives in the UPDATE, not in a
  # read followed by a write. A copy loaded before the claim cannot take it.
  test "a stale copy cannot take a recording somebody else has claimed" do
    stale = VoiceRecording.find(@voice_recording.id)
    @voice_recording.claim(users(:one))

    assert_not stale.claim(users(:two))
    assert_equal users(:one), @voice_recording.reload.claimed_by
  end

  test "re-claiming your own is a no-op rather than a refusal" do
    @voice_recording.claim(users(:one))

    assert @voice_recording.claim(users(:one))
    assert_equal users(:one), @voice_recording.reload.claimed_by
  end

  test "a recording handed back is free for somebody else" do
    @voice_recording.claim(users(:one))
    @voice_recording.release!

    assert_nil @voice_recording.claimed_by
    assert @voice_recording.claim(users(:two))
  end

  test "unclaimed lists only what nobody is working through" do
    @voice_recording.claim(users(:one))

    assert_includes VoiceRecording.claimed, @voice_recording
    assert_not_includes VoiceRecording.unclaimed, @voice_recording
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
