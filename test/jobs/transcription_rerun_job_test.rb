# frozen_string_literal: true

require "test_helper"

class TranscriptionRerunJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @run = TranscriptionRun.create!(voice_recording: voice_recordings(:two), requested_by: users(:admin))
  end

  test "runs the re-transcription for the run" do
    Transcription::RerunOperation.expects(:call).with(transcription_run: @run).returns(stub(success?: true))

    assert_no_enqueued_emails do
      TranscriptionRerunJob.perform_now(@run.id)
    end
  end

  test "sends the failed-transcription email when the run fails" do
    Transcription::RerunOperation.stubs(:call).returns(stub(success?: false).tap { |result| result.stubs(:[]).with(:error).returns("Upload error: boom") })

    assert_enqueued_email_with NotificationsMailer, :transcription_failed, args: [@run.voice_recording, "Re-transcription: Upload error: boom"] do
      TranscriptionRerunJob.perform_now(@run.id)
    end
  end

  test "a run that already finished is not run again or reported as failed" do
    @run.update!(status: :ready, fotheidil_video_id: "9001", finished_at: Time.current)
    Transcription::RerunOperation.expects(:call).never

    assert_no_enqueued_emails do
      TranscriptionRerunJob.perform_now(@run.id)
    end
  end

  test "a deleted run is dropped quietly" do
    Transcription::RerunOperation.expects(:call).never

    assert_nothing_raised { TranscriptionRerunJob.perform_now(0) }
  end

  test "shares one Fotheidil slot with the import pipeline" do
    rerun = TranscriptionRerunJob.new(@run.id)
    import = ProcessFotheidilVideoJob.new(@run.voice_recording_id)

    assert_equal import.concurrency_key, rerun.concurrency_key
    assert_equal 1, TranscriptionRerunJob.concurrency_limit
  end
end
