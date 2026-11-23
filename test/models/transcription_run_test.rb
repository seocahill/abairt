require "test_helper"

class TranscriptionRunTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:two)
    @recording.update!(fotheidil_video_id: "old-job", segments: [{"start" => 0.0, "end" => 5.0, "text" => "current"}])
  end

  def build_run(**attrs)
    TranscriptionRun.new(voice_recording: @recording, requested_by: users(:admin), **attrs)
  end

  test "a new run is pending with no segments" do
    run = build_run
    assert run.save
    assert run.pending?
    assert_equal [], run.segments
  end

  test "keeps the raw segments as a list" do
    segments = [{"start" => 0.0, "end" => 2.5, "text" => "x", "speaker" => "SPEAKER_01"}]
    run = build_run(segments: segments, fotheidil_video_id: "new-job")
    assert run.save
    assert_equal segments, run.reload.segments
  end

  test "segments must be a list" do
    run = build_run(segments: {"start" => 0})
    assert_not run.valid?
    assert_includes run.errors[:segments], "must be a list"
  end

  test "never reuses the recording's existing Fotheidil job" do
    run = build_run(fotheidil_video_id: "old-job")
    assert_not run.valid?
    assert run.errors[:fotheidil_video_id].any?
  end

  test "never reuses a job held by a copy of the recording" do
    voice_recordings(:one).update!(fotheidil_video_id: "copied-job")
    run = build_run(fotheidil_video_id: "copied-job")
    assert_not run.valid?
    assert run.errors[:fotheidil_video_id].any?
  end

  test "a ready run has its new job and when it finished" do
    run = build_run(status: :ready)
    assert_not run.valid?
    assert run.errors[:fotheidil_video_id].any?
    assert run.errors[:finished_at].any?

    run.assign_attributes(fotheidil_video_id: "new-job", finished_at: Time.current)
    assert run.valid?
  end

  test "a failed run records when it stopped and why" do
    run = build_run(status: :failed)
    assert_not run.valid?
    assert run.errors[:finished_at].any?

    run.assign_attributes(finished_at: Time.current, error: "Fotheidil timed out")
    assert run.save
    assert_equal "Fotheidil timed out", run.reload.error
  end

  test "who asked for a run cannot be deleted while it exists" do
    build_run.save!
    assert_not users(:admin).destroy
    assert User.exists?(users(:admin).id)
  end

  test "never reuses another run's Fotheidil job" do
    build_run(fotheidil_video_id: "new-job").save!
    run = build_run(fotheidil_video_id: "new-job")
    assert_not run.valid?
    assert run.errors[:fotheidil_video_id].any?
  end

  test "several runs can wait for a job id" do
    build_run.save!
    assert build_run.valid?
  end

  test "cannot finish before it started" do
    run = build_run(started_at: 1.minute.ago, finished_at: 2.minutes.ago)
    assert_not run.valid?
    assert run.errors[:finished_at].any?
  end

  test "requires a recording and who asked for it" do
    run = TranscriptionRun.new
    assert_not run.valid?
    assert run.errors[:voice_recording].any?
    assert run.errors[:requested_by].any?
  end

  test "saving a run leaves the recording, its segments and its entries alone" do
    before_segments = @recording.reload.segments
    entry_texts = @recording.dictionary_entries.pluck(:id, :word_or_phrase, :translation)
    entry_versions = PaperTrail::Version.where(item_type: "DictionaryEntry").count

    run = build_run(fotheidil_video_id: "new-job", segments: [{"start" => 0, "end" => 1, "text" => "x"}], status: :ready, finished_at: Time.current)
    run.save!
    run.transcription_candidates.create!(kind: :new_segment, region_start: 0, region_end: 1, word_or_phrase: "x")

    assert_equal before_segments, @recording.reload.segments
    assert_equal "old-job", @recording.fotheidil_video_id
    assert_equal entry_texts, @recording.dictionary_entries.pluck(:id, :word_or_phrase, :translation)
    assert_equal entry_versions, PaperTrail::Version.where(item_type: "DictionaryEntry").count
  end

  test "goes with its recording, candidates and all" do
    run = build_run
    run.save!
    run.transcription_candidates.create!(kind: :new_segment, region_start: 0, region_end: 1, word_or_phrase: "x")

    assert_difference -> { TranscriptionRun.count } => -1, -> { TranscriptionCandidate.count } => -1 do
      @recording.destroy
    end
  end
end
