require "test_helper"

class Transcription::AcceptAllTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @recording = voice_recordings(:two)
    @recording.dictionary_entries.destroy_all
    @owner = users(:two)
    @admin = users(:admin)
    @run = TranscriptionRun.create!(voice_recording: @recording, requested_by: @admin)
    @run.update!(status: :ready, fotheidil_video_id: "rerun-1", started_at: 1.minute.ago, finished_at: Time.current)
  end

  def entry(text, **attrs)
    DictionaryEntry.create!({voice_recording: @recording, owner: @owner, word_or_phrase: text, region_start: 1, region_end: 3}.merge(attrs))
  end

  def candidate(entry, text, kind: :differs, **attrs)
    @run.transcription_candidates.create!({kind:, dictionary_entry: entry, region_start: 12, region_end: 15, word_or_phrase: text}.merge(attrs))
  end

  test "the new text goes on unconfirmed lines, and the lines changed since the page was seen are counted" do
    fresh = entry("one two")
    changed = entry("three four")
    candidate(fresh, "one too")
    candidate(changed, "three for")
    seen_at = Time.current
    travel 1.second
    changed.update!(word_or_phrase: "a correction meanwhile")

    assert_equal({accepted: 1, skipped: 1}, Transcription::AcceptAll.call(@run, by: @admin, seen_at:))
    assert_equal "one too", fresh.reload.word_or_phrase
    assert_equal "a correction meanwhile", changed.reload.word_or_phrase
  end

  test "lines that differ only in case or punctuation are left when they are hidden" do
    cosmetic = entry("tá sé go maith")
    real = entry("bhí sé ann")
    candidate(cosmetic, "Tá sé go maith.")
    candidate(real, "bhí sí ann")

    result = Transcription::AcceptAll.call(@run, by: @admin, seen_at: 1.minute.from_now, hide_cosmetic: true)

    assert_equal({accepted: 1, skipped: 0}, result)
    assert_equal "tá sé go maith", cosmetic.reload.word_or_phrase
    assert_equal "bhí sí ann", real.reload.word_or_phrase
  end

  test "timing is set on every line without times, and text is never touched" do
    one = entry("copied one", region_start: nil, region_end: nil)
    two = entry("copied two", region_start: nil, region_end: nil, accuracy_status: :confirmed)
    candidate(one, "copied one", kind: :timing, region_start: 10, region_end: 14)
    candidate(two, "copied two", kind: :timing, region_start: 14, region_end: 18)
    differing = candidate(entry("other line"), "other lines")

    assert_equal({accepted: 2, skipped: 0}, Transcription::AcceptAll.call(@run, by: @admin, seen_at: Time.current, kind: :timing))

    assert_equal [10, 14], [one.reload.region_start, one.region_end]
    assert_equal [14, 18], [two.reload.region_start, two.region_end]
    assert_equal ["copied one", "copied two"], [one.word_or_phrase, two.word_or_phrase]
    assert differing.reload.pending?
  end

  test "timing is not held back by an edit since the page was seen" do
    line = entry("copied one", region_start: nil, region_end: nil)
    candidate(line, "copied one", kind: :timing, region_start: 10, region_end: 14)
    seen_at = Time.current
    travel 1.second
    line.update!(translation: "typed meanwhile")

    assert_equal({accepted: 1, skipped: 0}, Transcription::AcceptAll.call(@run, by: @admin, seen_at:, kind: :timing))
    assert_equal "typed meanwhile", line.reload.translation
  end
end
