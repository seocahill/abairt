require 'test_helper'

class DiarizeVoiceRecordingJobTest < ActiveJob::TestCase
  test "performs diarization for voice recording" do
    voice_recording = voice_recordings(:one)
    mock_service = mock('DiarizationService')

    DiarizationService.expects(:new)
                     .with(voice_recording)
                     .returns(mock_service)

    mock_service.expects(:diarize).returns(true)

    DiarizeVoiceRecordingJob.perform_now(voice_recording.id)
  end

  test "handles non-existent voice recording" do
    assert_raises(ActiveRecord::RecordNotFound) do
      DiarizeVoiceRecordingJob.perform_now(-1)
    end
  end
end
