require 'test_helper'

class NightlyTranscribeJobTest < ActiveJob::TestCase
  def setup
    @test_media_file = Tempfile.new(['test_media', '.json'])
    @media_file_path = @test_media_file.path
  end

  def teardown
    @test_media_file.close
    @test_media_file.unlink
  end

  test "handles case when no recordings need diarization" do
    VoiceRecording.update_all(diarization_status: 'completed')

    # Stub import to prevent modifying production file
    VoiceRecording.stubs(:import_from_archive).returns(nil)

    # Should not enqueue any jobs
    assert_no_enqueued_jobs(only: ProcessFotheidilVideoJob) do
      NightlyTranscribeJob.perform_now
    end
  end

  test "only processes recordings with attached media" do
    # Make sure no recordings have media attached
    VoiceRecording.all.each { |vr| vr.media.purge if vr.media.attached? }
    VoiceRecording.update_all(diarization_status: nil)

    # Stub import to prevent modifying production file
    VoiceRecording.stubs(:import_from_archive).returns(nil)

    # Should not enqueue any jobs
    assert_no_enqueued_jobs(only: ProcessFotheidilVideoJob) do
      NightlyTranscribeJob.perform_now
    end
  end
end