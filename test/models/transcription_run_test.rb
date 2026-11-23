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
    assert TranscriptionRun.new(voice_recording: voice_recordings(:one), requested_by: users(:admin)).valid?
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

  test "a recording has one open re-transcription at a time" do
    first = build_run
    first.save!
    second = build_run
    assert_not second.valid?
    assert_match(/already running/, second.errors.full_messages.to_sentence)

    first.update!(status: :ready, fotheidil_video_id: "new-job", finished_at: Time.current)
    candidate = first.transcription_candidates.create!(kind: :new_segment, region_start: 0, region_end: 1, word_or_phrase: "x")
    assert_not second.valid?
    assert_match(/Review or dismiss/, second.errors.full_messages.to_sentence)

    candidate.dismiss(by: users(:admin))
    assert second.valid?, second.errors.full_messages.to_sentence
  end

  test "dismissing a run dismisses only what is still waiting" do
    run = build_run(fotheidil_video_id: "new-job", status: :ready, finished_at: Time.current)
    run.save!
    waiting = 2.times.map { |n| run.transcription_candidates.create!(kind: :new_segment, region_start: n, region_end: n + 1, word_or_phrase: "x") }
    done = run.transcription_candidates.create!(kind: :new_segment, region_start: 5, region_end: 6, word_or_phrase: "x")
    done.dismiss(by: users(:two))

    assert_equal 2, run.dismiss_pending(by: users(:admin))
    assert waiting.all? { |c| c.reload.dismissed? && c.resolved_by == users(:admin) }
    assert_equal users(:two), done.reload.resolved_by
    assert_not run.reload.awaiting_review?
  end

  test "a run lost while pending stops blocking the recording and can be closed" do
    lost = build_run(created_at: 3.hours.ago)
    lost.save!
    assert lost.abandoned?
    assert_includes TranscriptionRun.abandoned, lost
    assert build_run.valid?

    lost.abandon!
    assert lost.reload.failed?
    assert_match(/job was lost/, lost.error)
    assert_not build_run(created_at: 1.hour.ago).tap(&:save!).abandoned?
  end
end
