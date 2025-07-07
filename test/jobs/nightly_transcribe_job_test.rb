require 'test_helper'

class NightlyTranscribeJobTest < ActiveJob::TestCase
  test "performs diarization for most recent un-diarized recording" do
    # Create recordings with different statuses
    old_recording = voice_recordings(:one)
    old_recording.update(diarization_status: nil, created_at: 2.days.ago)
    old_recording.media.attach(io: File.open(Rails.root.join('test/fixtures/files/deasaigh.mp3')), filename: 'old.mp3')
    
    recent_recording = voice_recordings(:two)
    recent_recording.update(diarization_status: nil, created_at: 1.day.ago)
    recent_recording.media.attach(io: File.open(Rails.root.join('test/fixtures/files/deasaigh.mp3')), filename: 'recent.mp3')

    # Mock the service
    mock_service = mock('DiarizationService')
    DiarizationService.expects(:new)
                     .with(recent_recording)
                     .returns(mock_service)
    mock_service.expects(:diarize).returns(true)

    NightlyTranscribeJob.perform_now
  end

  test "handles case when no recordings need diarization" do
    VoiceRecording.update_all(diarization_status: 'completed')
    
    # Should not call DiarizationService
    DiarizationService.expects(:new).never
    
    NightlyTranscribeJob.perform_now
  end

  test "only processes recordings with attached media" do
    # Make sure no recordings have media attached
    VoiceRecording.all.each { |vr| vr.media.purge if vr.media.attached? }
    VoiceRecording.update_all(diarization_status: nil)
    
    # Should not call DiarizationService
    DiarizationService.expects(:new).never
    
    NightlyTranscribeJob.perform_now
  end
end