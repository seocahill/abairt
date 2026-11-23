require "test_helper"

class TranscriptionCandidateTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:two)
    @run = TranscriptionRun.create!(voice_recording: @recording, requested_by: users(:admin))
    @entry = dictionary_entries(:one)
    @entry.update_columns(voice_recording_id: @recording.id)
  end

  def build_candidate(**attrs)
    @run.transcription_candidates.new({region_start: 1.0, region_end: 2.5, word_or_phrase: "x"}.merge(attrs))
  end

  test "a candidate for a current entry starts pending" do
    candidate = build_candidate(dictionary_entry: @entry)
    assert candidate.save
    assert candidate.pending?
    assert_includes TranscriptionCandidate.differs, candidate
  end

  test "a new segment has no entry and keeps what is needed to add one" do
    candidate = build_candidate(kind: :new_segment, region_id: "seg-7", speaker_label: "SPEAKER_02")
    assert candidate.save
    assert_includes TranscriptionCandidate.new_segment, candidate
    assert_equal ["seg-7", "SPEAKER_02"], [candidate.reload.region_id, candidate.speaker_label]
  end

  test "a candidate that differs needs the entry it differs from" do
    candidate = build_candidate
    assert candidate.differs?
    assert_not candidate.valid?
    assert candidate.errors[:dictionary_entry].any?
  end

  test "one candidate per entry in a run" do
    build_candidate(dictionary_entry: @entry).save!
    duplicate = build_candidate(dictionary_entry: @entry)
    assert_not duplicate.valid?
    assert duplicate.errors[:dictionary_entry_id].any?

    assert build_candidate(kind: :new_segment).save
    assert build_candidate(kind: :new_segment).save
  end

  test "a pending candidate has not been resolved by anyone" do
    candidate = build_candidate(dictionary_entry: @entry, resolved_by: users(:admin), resolved_at: Time.current)
    assert_not candidate.valid?
    assert candidate.errors[:resolved_by].any?
  end

  test "who resolved a candidate cannot be deleted while it exists" do
    build_candidate(dictionary_entry: @entry, status: :dismissed, resolved_by: users(:speaker), resolved_at: Time.current).save!
    assert_not users(:speaker).destroy
  end

  test "needs text" do
    candidate = build_candidate(kind: :new_segment, word_or_phrase: " ")
    assert_not candidate.valid?
    assert candidate.errors[:word_or_phrase].any?
  end

  test "must end after it starts" do
    candidate = build_candidate(kind: :new_segment, region_start: 3, region_end: 3)
    assert_not candidate.valid?
    assert candidate.errors[:region_end].any?
  end

  test "cannot start before the recording does" do
    candidate = build_candidate(kind: :new_segment, region_start: -1)
    assert_not candidate.valid?
    assert candidate.errors[:region_start].any?
  end

  test "the entry must be from the run's recording" do
    @entry.update_columns(voice_recording_id: voice_recordings(:one).id)
    candidate = build_candidate(dictionary_entry: @entry)
    assert_not candidate.valid?
    assert candidate.errors[:dictionary_entry].any?
  end

  test "accepting or dismissing records who and when" do
    candidate = build_candidate(dictionary_entry: @entry, status: :accepted)
    assert_not candidate.valid?
    assert candidate.errors[:resolved_by].any?
    assert candidate.errors[:resolved_at].any?

    candidate.assign_attributes(resolved_by: users(:admin), resolved_at: Time.current)
    assert candidate.valid?
  end

  test "goes when its entry is deleted" do
    build_candidate(dictionary_entry: @entry).save!
    assert_difference -> { TranscriptionCandidate.count }, -1 do
      @entry.destroy
    end
  end

  test "dismissing records who and when, once" do
    candidate = build_candidate(dictionary_entry: @entry)
    candidate.save!

    assert candidate.dismiss(by: users(:admin))
    assert candidate.reload.dismissed?
    assert_equal users(:admin), candidate.resolved_by
    assert_not candidate.dismiss(by: users(:two))
    assert_equal users(:admin), candidate.reload.resolved_by
  end

  test "an entry's translation is stale while it is the one kept when new Irish was used" do
    @entry.update_columns(translation: "kept translation")
    candidate = build_candidate(dictionary_entry: @entry)
    candidate.save!
    assert_empty TranscriptionCandidate.stale_translation_entry_ids([@entry])

    candidate.update!(status: :accepted, resolved_by: users(:admin), resolved_at: Time.current, translation_at_acceptance: "kept translation")
    assert_equal Set[@entry.id], TranscriptionCandidate.stale_translation_entry_ids([@entry])

    @entry.update_columns(translation: "rechecked translation")
    assert_empty TranscriptionCandidate.stale_translation_entry_ids([@entry])
  end
end
