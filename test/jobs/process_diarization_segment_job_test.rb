require 'test_helper'

class ProcessDiarizationSegmentJobTest < ActiveJob::TestCase
  def setup
    @voice_recording = voice_recordings(:one)
    @segment_data = {
      'start' => 0.0,
      'end' => 5.0,
      'speaker' => 'SPEAKER_01'
    }
    @speaker_id = 'SPEAKER_01'
  end

  test "creates dictionary entry for segment" do
    # Mock the audio snippet creation to avoid actual audio processing
    DictionaryEntry.any_instance.expects(:create_audio_snippet)
    
    # Mock sleep to speed up test
    ProcessDiarizationSegmentJob.any_instance.expects(:sleep)
    
    assert_difference 'DictionaryEntry.count', 1 do
      ProcessDiarizationSegmentJob.perform_now(@voice_recording.id, @segment_data, @speaker_id)
    end
    
    entry = DictionaryEntry.last
    assert_equal @voice_recording, entry.voice_recording
    assert_equal @segment_data['start'], entry.region_start
    assert_equal @segment_data['end'], entry.region_end
    assert_equal "temporary", entry.speaker.role
  end

  test "skips creation when human entry overlaps" do
    # Create a human dictionary entry that overlaps (2.0-7.0 overlaps with 0.0-5.0)
    human_user = users(:one)
    DictionaryEntry.create!(
      voice_recording: @voice_recording,
      speaker: human_user,
      owner: @voice_recording.owner,
      region_start: 2.0,
      region_end: 7.0
    )
    
    # Mock sleep to speed up test
    ProcessDiarizationSegmentJob.any_instance.expects(:sleep)
    
    assert_no_difference 'DictionaryEntry.count' do
      ProcessDiarizationSegmentJob.perform_now(@voice_recording.id, @segment_data, @speaker_id)
    end
  end

  test "skips creation when human entry partially overlaps at start" do
    # Human entry 0.0-2.0 overlaps with machine segment 0.0-5.0
    human_user = users(:one)
    DictionaryEntry.create!(
      voice_recording: @voice_recording,
      speaker: human_user,
      owner: @voice_recording.owner,
      region_start: 0.0,
      region_end: 2.0
    )
    
    ProcessDiarizationSegmentJob.any_instance.expects(:sleep)
    
    assert_no_difference 'DictionaryEntry.count' do
      ProcessDiarizationSegmentJob.perform_now(@voice_recording.id, @segment_data, @speaker_id)
    end
  end

  test "skips creation when human entry partially overlaps at end" do
    # Human entry 4.0-8.0 overlaps with machine segment 0.0-5.0
    human_user = users(:one)
    DictionaryEntry.create!(
      voice_recording: @voice_recording,
      speaker: human_user,
      owner: @voice_recording.owner,
      region_start: 4.0,
      region_end: 8.0
    )
    
    ProcessDiarizationSegmentJob.any_instance.expects(:sleep)
    
    assert_no_difference 'DictionaryEntry.count' do
      ProcessDiarizationSegmentJob.perform_now(@voice_recording.id, @segment_data, @speaker_id)
    end
  end

  test "creates entry when human entries don't overlap" do
    # Human entry 10.0-15.0 doesn't overlap with machine segment 0.0-5.0
    human_user = users(:one)
    DictionaryEntry.create!(
      voice_recording: @voice_recording,
      speaker: human_user,
      owner: @voice_recording.owner,
      region_start: 10.0,
      region_end: 15.0
    )
    
    DictionaryEntry.any_instance.expects(:create_audio_snippet)
    ProcessDiarizationSegmentJob.any_instance.expects(:sleep)
    
    assert_difference 'DictionaryEntry.count', 1 do
      ProcessDiarizationSegmentJob.perform_now(@voice_recording.id, @segment_data, @speaker_id)
    end
  end

  test "creates entry when only temporary entries overlap" do
    # Create a temporary user entry that overlaps
    temp_user = User.create!(
      name: "temp_user",
      email: "temp@temporary.abairt",
      password: "password",
      role: :temporary
    )
    
    DictionaryEntry.create!(
      voice_recording: @voice_recording,
      speaker: temp_user,
      owner: @voice_recording.owner,
      region_start: 2.0,
      region_end: 7.0
    )
    
    # Mock the audio snippet creation and sleep
    DictionaryEntry.any_instance.expects(:create_audio_snippet)
    ProcessDiarizationSegmentJob.any_instance.expects(:sleep)
    
    assert_difference 'DictionaryEntry.count', 1 do
      ProcessDiarizationSegmentJob.perform_now(@voice_recording.id, @segment_data, @speaker_id)
    end
  end

  test "creates temporary speaker user" do
    # Mock the audio snippet creation and sleep
    DictionaryEntry.any_instance.expects(:create_audio_snippet)
    ProcessDiarizationSegmentJob.any_instance.expects(:sleep)
    
    assert_difference 'User.count', 1 do
      ProcessDiarizationSegmentJob.perform_now(@voice_recording.id, @segment_data, @speaker_id)
    end
    
    temp_user = User.last
    assert_equal "temporary", temp_user.role
    assert_includes temp_user.email, 'temporary.abairt'
  end
end