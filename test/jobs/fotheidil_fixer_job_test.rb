require "test_helper"

class FotheidilFixerJobTest < ActiveJob::TestCase
  def setup
    @owner = users(:one)
    # Clear any existing voice recordings from fixtures to avoid test pollution
    VoiceRecording.destroy_all
  end

  test "priority 1: retries voice recording with video_id but no segments" do
    vr = create_voice_recording_with_media(
      fotheidil_video_id: "123",
      segments: nil,
      diarization_status: "failed"
    )

    assert_enqueued_with(job: ProcessFotheidilVideoJob, args: [vr.id, "123"]) do
      FotheidilFixerJob.perform_now
    end
  end

  test "priority 2: retries voice recording with segments but incomplete entries" do
    vr = create_voice_recording_with_media(
      fotheidil_video_id: "456",
      segments: [{id: 1}, {id: 2}, {id: 3}],
      diarization_status: "processing"
    )
    vr.update(dictionary_entries_count: 2) # Only 2 of 3 entries created

    assert_enqueued_with(job: ProcessFotheidilVideoJob, args: [vr.id, "456"]) do
      FotheidilFixerJob.perform_now
    end
  end

  test "priority 3: retries voice recording with media but no video_id" do
    vr = create_voice_recording_with_media(
      fotheidil_video_id: nil,
      segments: nil,
      diarization_status: "failed"
    )

    assert_enqueued_with(job: ProcessFotheidilVideoJob, args: [vr.id, nil]) do
      FotheidilFixerJob.perform_now
    end
  end

  test "skips completed voice recordings" do
    VoiceRecording.destroy_all

    vr = create_voice_recording_with_media(
      fotheidil_video_id: "789",
      segments: [{id: 1}],
      diarization_status: "completed"
    )
    vr.update!(dictionary_entries_count: 1)

    assert_no_enqueued_jobs do
      FotheidilFixerJob.perform_now
    end
  end

  test "skips voice recordings with all entries created" do
    # Ensure we're testing in isolation - only create completed VR
    VoiceRecording.destroy_all

    vr = create_voice_recording_with_media(
      fotheidil_video_id: "999",
      segments: [{id: 1}, {id: 2}],
      diarization_status: "processing"
    )

    # Create actual dictionary entries to increment the counter cache
    2.times do |i|
      DictionaryEntry.create!(
        voice_recording: vr,
        speaker: @owner,
        owner: @owner,
        region_start: i.to_f,
        region_end: (i + 1).to_f,
        word_or_phrase: "test #{i}"
      )
    end

    vr.reload

    assert_no_enqueued_jobs do
      FotheidilFixerJob.perform_now
    end
  end

  test "processes most recent incomplete recording" do
    # Older recording - has video_id but no segments (priority 1)
    old_vr = create_voice_recording_with_media(
      fotheidil_video_id: "111",
      segments: nil,
      diarization_status: "failed",
      created_at: 2.days.ago
    )

    # More recent recording - also has video_id but no segments (priority 1)
    recent_vr = create_voice_recording_with_media(
      fotheidil_video_id: "222",
      segments: nil,
      diarization_status: "failed",
      created_at: 1.day.ago
    )

    # Should process the most recent one
    assert_enqueued_with(job: ProcessFotheidilVideoJob, args: [recent_vr.id, "222"]) do
      FotheidilFixerJob.perform_now
    end
  end

  private

  def create_voice_recording_with_media(fotheidil_video_id:, segments:, diarization_status:, created_at: Time.current)
    vr = VoiceRecording.create!(
      title: "Test Recording",
      owner: @owner,
      fotheidil_video_id: fotheidil_video_id,
      diarization_status: diarization_status,
      created_at: created_at
    )

    vr.diarization_data ||= {}
    vr.diarization_data["segments"] = segments
    vr.save!

    # Attach dummy media file
    vr.media.attach(
      io: StringIO.new("fake audio data"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )

    vr
  end
end
