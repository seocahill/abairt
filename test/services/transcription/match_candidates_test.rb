require "test_helper"

class Transcription::MatchCandidatesTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:two)
    @recording.update!(segments: [{"startTimeSeconds" => 0.0, "endTimeSeconds" => 5.0, "text" => "current", "speaker" => "SPEAKER_00", "id" => 1}])
    @run = TranscriptionRun.create!(voice_recording: @recording, requested_by: users(:admin))
    # Lines with no times are read in the order they were added.
    @entries = %i[one two three four].map { |name| dictionary_entries(name) }.sort_by(&:id)
  end

  # Puts a fixture entry on the recording at the given span (or with no times
  # at all, when `from` is nil) with the given text.
  def place(entry, from, to, text, **attrs)
    entry.update_columns(voice_recording_id: @recording.id, region_start: from, region_end: to, word_or_phrase: text, **attrs)
    entry
  end

  def segment(from, to, text, id: "#{from}-#{to}", speaker: "SPEAKER_00")
    {"id" => id, "startTimeSeconds" => from, "endTimeSeconds" => to, "text" => text, "speaker" => speaker}
  end

  def matcher_for(*segments)
    @run.update!(segments: segments)
    Transcription::MatchCandidates.new(@run)
  end

  def candidates_for(*segments)
    matcher_for(*segments).candidates
  end

  # --- Lines with times -----------------------------------------------------

  test "an exact match with the same text is left out" do
    place(@entries[0], 0.0, 5.0, "current text")
    assert_empty candidates_for(segment(0.0, 5.0, "current text"))
  end

  test "whitespace and how an accent is encoded are not a difference" do
    place(@entries[0], 0.0, 5.0, "café au lait")
    assert_empty candidates_for(segment(0.0, 5.0, "  café   au lait "))
  end

  test "case and punctuation are a difference, and are marked as only that" do
    place(@entries[0], 0.0, 5.0, "current text")
    candidate = candidates_for(segment(0.0, 5.0, "Current text.")).sole

    assert candidate.differs?
    assert candidate.cosmetic?
  end

  test "different words are not marked as only case or punctuation" do
    place(@entries[0], 0.0, 5.0, "current text")
    refute candidates_for(segment(0.0, 5.0, "Current texts.")).sole.cosmetic?
  end

  test "new text over a current entry is a candidate for that entry" do
    entry = place(@entries[0], 0.0, 5.0, "current text")
    candidate = candidates_for(segment(0.0, 5.0, "fresh text", id: 42, speaker: "SPEAKER_01")).sole

    assert candidate.differs?
    assert_equal entry, candidate.dictionary_entry
    assert_equal "fresh text", candidate.word_or_phrase
    assert_equal [0.0, 5.0, "42", "SPEAKER_01"], [candidate.region_start, candidate.region_end, candidate.region_id, candidate.speaker_label]
    assert candidate.pending?
  end

  test "boundaries that moved a little still line up" do
    entry = place(@entries[0], 10.0, 15.0, "current text")
    place(@entries[1], 15.0, 20.0, "next text")
    candidate = candidates_for(segment(10.4, 15.6, "fresh text"), segment(15.6, 20.0, "next text")).sole

    assert_equal entry, candidate.dictionary_entry
    assert_equal 10.4, candidate.region_start
  end

  test "an entry cut into two segments gets the words of both, not two new lines" do
    entry = place(@entries[0], 0.0, 10.0, "one two three four")
    candidate = candidates_for(segment(0.0, 5.0, "one two"), segment(5.0, 10.0, "three fore")).sole

    assert_equal entry, candidate.dictionary_entry
    assert_equal "one two three fore", candidate.word_or_phrase
    assert_equal [0.0, 10.0], [candidate.region_start, candidate.region_end]
  end

  test "two entries merged into one segment each get their own words" do
    place(@entries[0], 0.0, 5.0, "one two")
    second = place(@entries[1], 5.0, 10.0, "three four")
    candidate = candidates_for(segment(0.0, 10.0, "one two three fore")).sole

    assert_equal second, candidate.dictionary_entry
    assert_equal "three fore", candidate.word_or_phrase
  end

  test "lines cut in different places each get the words that belong to them" do
    first = place(@entries[0], 0.0, 6.0, "ar maidin inné")
    second = place(@entries[1], 6.0, 12.0, "bhí mé ag obair")
    candidates = candidates_for(segment(0.0, 4.0, "ar maidin"), segment(4.0, 12.0, "inniu bhí mé ag obair"))

    candidate = candidates.sole
    assert_equal first, candidate.dictionary_entry
    assert_equal "ar maidin inniu", candidate.word_or_phrase
    refute_equal second, candidate.dictionary_entry
  end

  test "someone talking over a turn does not stop the turn lining up" do
    place(@entries[0], 0.0, 10.0, "a long turn of talk")
    place(@entries[1], 4.0, 4.6, "yes")
    assert_empty candidates_for(segment(0.0, 10.0, "a long turn of talk", speaker: "A"), segment(4.0, 4.6, "yes", speaker: "B"))
  end

  test "a tiny overlap at a boundary does not join neighbours" do
    place(@entries[0], 0.0, 5.0, "one two")
    second = place(@entries[1], 4.9, 10.0, "three four")
    candidate = candidates_for(segment(0.0, 5.0, "one two"), segment(4.9, 10.0, "three fore")).sole

    assert_equal second, candidate.dictionary_entry
  end

  test "a segment over no entry is a new segment, with its id and speaker" do
    place(@entries[0], 0.0, 5.0, "current text")
    candidate = candidates_for(segment(0.0, 5.0, "current text"), segment(20.0, 25.0, "something new", id: 7, speaker: "SPEAKER_02")).sole

    assert candidate.new_segment?
    assert_nil candidate.dictionary_entry
    assert_equal ["something new", 20.0, 25.0, "7", "SPEAKER_02"], [candidate.word_or_phrase, candidate.region_start, candidate.region_end, candidate.region_id, candidate.speaker_label]
  end

  test "words heard between two lines that neither one has are a new segment" do
    place(@entries[0], 0.0, 5.0, "one two")
    place(@entries[1], 10.0, 15.0, "five six")
    candidate = candidates_for(segment(0.0, 5.0, "one two"), segment(5.0, 10.0, "three four"), segment(10.0, 15.0, "five six")).sole

    assert candidate.new_segment?
    assert_equal "three four", candidate.word_or_phrase
  end

  test "a confirmed entry still gets its candidate, for the review to show read-only" do
    place(@entries[0], 0.0, 5.0, "current text", accuracy_status: 1)
    assert candidates_for(segment(0.0, 5.0, "fresh text")).sole.differs?
  end

  # --- Lines the new transcription does not have -----------------------------

  test "a line no segment touches is not heard, and gets no candidate" do
    heard = place(@entries[0], 0.0, 5.0, "current text")
    silent = place(@entries[1], 20.0, 25.0, "nobody said this")
    matcher = matcher_for(segment(0.0, 5.0, "current text"))

    assert_empty matcher.candidates
    assert_equal [silent], matcher.unheard_entries
    refute_includes matcher.unheard_entries, heard
  end

  test "lines from other recordings, without text, or with half a time are not looked at" do
    other = place(@entries[0], 0.0, 5.0, "elsewhere")
    other.update_columns(voice_recording_id: voice_recordings(:one).id)
    place(@entries[1], 0.0, 5.0, "")
    place(@entries[2], 8.0, nil, "half a time")
    place(@entries[3], 9.0, 9.0, "backwards")
    matcher = matcher_for(segment(30.0, 35.0, "fresh"))

    assert_equal ["fresh"], matcher.candidates.map(&:word_or_phrase)
    assert_empty matcher.unheard_entries
  end

  test "segments missing times or text, or running backwards, are skipped" do
    assert_empty candidates_for(
      segment(0.0, 5.0, ""),
      segment(5.0, 5.0, "no length"),
      segment(8.0, 6.0, "backwards"),
      {"id" => 1, "text" => "no times"},
      {"id" => 2, "startTimeSeconds" => "soon", "endTimeSeconds" => 3, "text" => "garbled"},
      "not a hash"
    )
  end

  test "an empty run has no candidates, and every timed line is unheard" do
    place(@entries[0], 0.0, 5.0, "current text")
    matcher = matcher_for
    assert_empty matcher.candidates
    assert_equal [@entries[0]], matcher.unheard_entries
  end

  # --- Lines with no times: typed in, or copied from elsewhere --------------

  test "a copied line gets times from where its words are heard, and its text is kept" do
    entry = place(@entries[0], nil, nil, "ar maidin inniu")
    candidate = candidates_for(segment(10.0, 16.0, "ar maidin inniu")).sole

    assert candidate.timing?
    assert_equal entry, candidate.dictionary_entry
    assert_equal [10.0, 16.0, "ar maidin inniu"], [candidate.region_start, candidate.region_end, candidate.word_or_phrase]
  end

  test "lines that share a segment get a share of its time each" do
    place(@entries[0], nil, nil, "one two")
    place(@entries[1], nil, nil, "three four")
    first, second = candidates_for(segment(10.0, 18.0, "one two three four"))

    assert_equal [10.0, 14.0], [first.region_start, first.region_end]
    assert_equal [14.0, 18.0], [second.region_start, second.region_end]
  end

  test "a copied line the new transcription spells differently gets new text and times" do
    entry = place(@entries[0], nil, nil, "tá an lá go deas inniu")
    candidates = candidates_for(segment(10.0, 16.0, "tá an lá go dheas inniu"))

    assert_equal %w[differs timing], candidates.map(&:kind).sort
    differs = candidates.find(&:differs?)
    assert_equal [entry, "tá an lá go dheas inniu"], [differs.dictionary_entry, differs.word_or_phrase]
    assert_equal [10.0, 16.0], candidates.find(&:timing?).then { [it.region_start, it.region_end] }
  end

  test "copied lines come out in the order they were added, whatever the times" do
    place(@entries[0], nil, nil, "one two three")
    place(@entries[1], nil, nil, "four five six")
    first, second = candidates_for(segment(0.0, 3.0, "one two three"), segment(3.0, 6.0, "four five six")).sort_by(&:region_start)

    assert_equal [@entries[0], @entries[1]], [first.dictionary_entry, second.dictionary_entry]
  end

  test "a copied line the new transcription has nothing like is unheard, and what was heard is new" do
    place(@entries[0], nil, nil, "this was never said")
    matcher = matcher_for(segment(0.0, 5.0, "something else entirely"))

    assert_equal [@entries[0]], matcher.unheard_entries
    assert matcher.candidates.sole.new_segment?
  end

  test "a copied line that shares too little with the new transcription is not matched" do
    place(@entries[0], nil, nil, "one two three four five six seven eight nine ten")
    matcher = matcher_for(segment(0.0, 5.0, "one nothing like it at all really truly madly"))

    assert_equal [@entries[0]], matcher.unheard_entries
    assert matcher.candidates.sole.new_segment?
  end

  test "lines with times and lines without are each matched on their own" do
    timed = place(@entries[0], 0.0, 5.0, "one two")
    copied = place(@entries[1], nil, nil, "seven eight")
    candidates = candidates_for(segment(0.0, 5.0, "one too"), segment(40.0, 45.0, "seven eight"))

    assert_equal [[timed, "differs"], [copied, "timing"]], candidates.map { [it.dictionary_entry, it.kind] }
  end

  # --- Saving ---------------------------------------------------------------

  test "building candidates saves nothing" do
    place(@entries[0], 0.0, 5.0, "current text")
    assert_no_difference "TranscriptionCandidate.count" do
      candidates_for(segment(0.0, 5.0, "fresh text"))
    end
  end

  test "candidates come back in time order and are valid" do
    place(@entries[0], 0.0, 5.0, "one")
    place(@entries[1], nil, nil, "two")
    candidates = candidates_for(segment(30.0, 34.0, "later"), segment(0.0, 5.0, "fresh"), segment(10.0, 12.0, "two"))

    assert_equal candidates.sort_by(&:region_start), candidates
    assert candidates.all?(&:valid?), candidates.map { it.errors.full_messages }.inspect
  end

  test "call saves the candidates against the run, and the lines not heard" do
    place(@entries[0], 0.0, 5.0, "current text")
    silent = place(@entries[1], 50.0, 55.0, "nobody said this")
    @run.update!(segments: [segment(0.0, 5.0, "fresh text"), segment(30.0, 34.0, "something new")])

    saved = Transcription::MatchCandidates.call(@run)

    assert_equal 2, saved.size
    assert saved.all?(&:persisted?)
    assert_equal saved.sort_by(&:id), @run.transcription_candidates.order(:id).to_a
    assert_equal [silent.id], @run.reload.unheard_entry_ids
    assert_equal [silent], @run.unheard_entries.to_a
  end

  test "a line can have both a new text and a timing candidate in one run" do
    place(@entries[0], nil, nil, "tá an lá go deas")
    @run.update!(segments: [segment(10.0, 16.0, "tá an lá go dheas")])

    assert_difference "TranscriptionCandidate.count", 2 do
      Transcription::MatchCandidates.call(@run)
    end
  end

  test "calling it again keeps the candidates and the decisions on them" do
    place(@entries[0], 0.0, 5.0, "current text")
    @run.update!(segments: [segment(0.0, 5.0, "fresh text")])
    first = Transcription::MatchCandidates.call(@run).sole
    first.update!(status: :dismissed, resolved_by: users(:admin), resolved_at: Time.current)

    assert_no_difference "TranscriptionCandidate.count" do
      assert_equal [first], Transcription::MatchCandidates.call(@run)
    end
    assert first.reload.dismissed?
  end

  test "matching changes no entry, translation or recording segments" do
    entries = [place(@entries[0], 0.0, 5.0, "current text"), place(@entries[1], nil, nil, "next text")]
    before = entries.map { |e| e.reload.attributes.slice("word_or_phrase", "translation", "accuracy_status", "region_start", "region_end", "updated_at") }
    recording_before = @recording.reload.diarization_data
    @run.update!(segments: [segment(0.0, 5.0, "fresh text"), segment(5.0, 10.0, "next text"), segment(30.0, 34.0, "new")])

    assert_no_difference ["PaperTrail::Version.count", "DictionaryEntry.count"] do
      assert_equal 3, Transcription::MatchCandidates.call(@run).size
    end
    assert_equal before, entries.map { |e| e.reload.attributes.slice("word_or_phrase", "translation", "accuracy_status", "region_start", "region_end", "updated_at") }
    assert_equal recording_before, @recording.reload.diarization_data
  end

  # --- A real recording ------------------------------------------------------

  # Real Fotheidil timings (395 segments, speakers overlapping), with the
  # text replaced by placeholders.
  def real_timings
    JSON.parse(file_fixture("fotheidil_video_1141_segments.json").read).each_with_index.map do |raw, i|
      raw.slice("id", "speaker", "startTimeSeconds", "endTimeSeconds").merge("text" => "line #{i}")
    end
  end

  def place_entries_for(timings, timed: true)
    rows = timings.map do |raw|
      {voice_recording_id: @recording.id, speaker_id: @entries[0].speaker_id, user_id: @entries[0].user_id,
       region_start: (raw["startTimeSeconds"] if timed), region_end: (raw["endTimeSeconds"] if timed), region_id: raw["id"],
       word_or_phrase: raw["text"], created_at: Time.current, updated_at: Time.current}
    end
    DictionaryEntry.insert_all!(rows)
  end

  test "re-running a real recording with the same output finds nothing to review" do
    timings = real_timings
    place_entries_for(timings)
    matcher = matcher_for(*timings)

    assert_empty matcher.candidates
    assert_empty matcher.unheard_entries
  end

  test "re-running a real recording with every line changed finds a changed line for every entry" do
    timings = real_timings
    place_entries_for(timings)
    candidates = candidates_for(*timings.map { |raw| raw.merge("text" => "#{raw["text"]} changed") })

    assert candidates.all?(&:differs?)
    assert_equal timings.size, candidates.map(&:dictionary_entry).uniq.size
  end

  test "a real recording whose lines were copied in with no times gets a time for every line" do
    timings = real_timings
    place_entries_for(timings, timed: false)
    candidates = candidates_for(*timings)

    assert candidates.all?(&:timing?)
    assert_equal timings.size, candidates.size
    assert candidates.all?(&:valid?)
  end

  test "a real recording is matched in a few queries, without a query per segment" do
    timings = real_timings
    place_entries_for(timings)
    @run.update!(segments: timings)

    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      Transcription::MatchCandidates.new(@run).candidates
    end

    assert_operator queries, :<=, 2
  end
end
