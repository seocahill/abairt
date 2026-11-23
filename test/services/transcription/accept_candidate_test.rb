require "test_helper"

class Transcription::AcceptCandidateTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @recording = voice_recordings(:two)
    @recording.dictionary_entries.destroy_all
    @owner = users(:two)
    @entry = DictionaryEntry.create!(voice_recording: @recording, owner: @owner, speaker: users(:four),
      word_or_phrase: "old words here", translation: "the translation", region_start: 1, region_end: 3)
    @run = TranscriptionRun.create!(voice_recording: @recording, requested_by: users(:admin))
    @run.update!(status: :ready, fotheidil_video_id: "rerun-1", started_at: 1.minute.ago, finished_at: Time.current)
  end

  def differs(**attrs)
    @run.transcription_candidates.create!({dictionary_entry: @entry, region_start: 1, region_end: 3, word_or_phrase: "new words here"}.merge(attrs))
  end

  def new_segment(**attrs)
    @run.transcription_candidates.create!({kind: :new_segment, region_start: 5, region_end: 7, region_id: "seg-9", speaker_label: "SPEAKER_03", word_or_phrase: "a new line"}.merge(attrs))
  end

  test "using new text updates the entry through a versioned save and keeps the translation" do
    candidate = differs

    assert_difference -> { @entry.versions.count }, 1 do
      assert Transcription::AcceptCandidate.call(candidate, by: @owner, current_text: "old words here")
    end

    @entry.reload
    assert_equal "new words here", @entry.word_or_phrase
    assert_equal "the translation", @entry.translation
    assert_equal "old words here", @entry.versions.last.reify.word_or_phrase
    candidate.reload
    assert candidate.accepted?
    assert_equal [@owner, "the translation"], [candidate.resolved_by, candidate.translation_at_acceptance]
    assert candidate.resolved_at
  end

  test "a confirmed entry is never changed" do
    @entry.update!(accuracy_status: :confirmed)
    candidate = differs
    service = Transcription::AcceptCandidate.new(candidate, by: @owner)

    assert_not service.call
    assert_match(/Deconfirm it first/, service.error)
    assert_equal "old words here", @entry.reload.word_or_phrase
    assert candidate.reload.pending?
  end

  test "an entry changed since the page was loaded is left alone" do
    candidate = differs
    @entry.update!(word_or_phrase: "a correction meanwhile")
    service = Transcription::AcceptCandidate.new(candidate, by: @owner, current_text: "old words here")

    assert_not service.call
    assert_match(/changed since/, service.error)
    assert_equal "a correction meanwhile", @entry.reload.word_or_phrase
    assert candidate.reload.pending?
  end

  test "a candidate already resolved is not resolved again" do
    candidate = differs
    candidate.dismiss(by: @owner)
    service = Transcription::AcceptCandidate.new(candidate, by: @owner)

    assert_not service.call
    assert_match(/already been dismissed/, service.error)
    assert_equal "old words here", @entry.reload.word_or_phrase
  end

  test "an invalid change rolls back and says why" do
    candidate = differs
    DictionaryEntry.any_instance.stubs(:update!).raises(ActiveRecord::RecordInvalid.new(@entry.tap { |e| e.errors.add(:base, "Nope") }))
    service = Transcription::AcceptCandidate.new(candidate, by: @owner)

    assert_not service.call
    assert_equal "Nope", service.error
    assert candidate.reload.pending?
  end

  test "adding a new line creates an unconfirmed entry, keeps the raw text and post-processes it" do
    candidate = new_segment

    assert_enqueued_with(job: PostProcessEntryJob) do
      assert Transcription::AcceptCandidate.call(candidate, by: @owner)
    end

    entry = candidate.reload.dictionary_entry
    assert candidate.accepted?
    assert entry.unconfirmed?
    assert_equal ["a new line", 5, 7, "seg-9", @recording.owner, nil],
      [entry.word_or_phrase, entry.region_start, entry.region_end, entry.region_id, entry.owner, entry.speaker]
    assert_equal ["a new line"], entry.asr_hypotheses.pluck(:text)
  end

  test "adding a new line isn't held to the import's segment count" do
    @recording.update!(diarization_data: {"segments" => [{"startTimeSeconds" => 1, "endTimeSeconds" => 3}]})
    assert_equal 1, @recording.segments_count

    assert Transcription::AcceptCandidate.call(new_segment, by: @owner)
    assert_equal 2, @recording.dictionary_entries.count
  end

  test "accept all uses the new text on unconfirmed differing lines only" do
    confirmed = DictionaryEntry.create!(voice_recording: @recording, owner: @owner, word_or_phrase: "kept as is",
      region_start: 10, region_end: 12, accuracy_status: :confirmed)
    differs
    @run.transcription_candidates.create!(dictionary_entry: confirmed, region_start: 10, region_end: 12, word_or_phrase: "would replace it")
    added = new_segment

    assert_equal 1, Transcription::AcceptAll.call(@run, by: @owner)
    assert_equal "new words here", @entry.reload.word_or_phrase
    assert_equal "kept as is", confirmed.reload.word_or_phrase
    assert added.reload.pending?
    assert_equal 2, @run.transcription_candidates.pending.count
  end
end
