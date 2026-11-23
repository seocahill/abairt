require "test_helper"

class Transcription::MatchCandidatesTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:two)
    @recording.update!(segments: [{"startTimeSeconds" => 0.0, "endTimeSeconds" => 5.0, "text" => "current", "speaker" => "SPEAKER_00", "id" => 1}])
    @run = TranscriptionRun.create!(voice_recording: @recording, requested_by: users(:admin))
    @entries = %i[one two three four].map { |name| dictionary_entries(name) }
  end

  # Puts a fixture entry on the recording at the given span with placeholder text.
  def place(entry, from, to, text, **attrs)
    entry.update_columns(voice_recording_id: @recording.id, region_start: from, region_end: to, word_or_phrase: text, **attrs)
    entry
  end

  def segment(from, to, text, id: "#{from}-#{to}", speaker: "SPEAKER_00")
    {"id" => id, "startTimeSeconds" => from, "endTimeSeconds" => to, "text" => text, "speaker" => speaker}
  end

  def candidates_for(*segments)
    @run.update!(segments: segments)
    Transcription::MatchCandidates.new(@run).candidates
  end

  test "an exact match with the same text is left out" do
    place(@entries[0], 0.0, 5.0, "current text")
    assert_empty candidates_for(segment(0.0, 5.0, "current text"))
  end

  test "whitespace and how an accent is encoded are not a difference" do
    place(@entries[0], 0.0, 5.0, "café au lait")
    assert_empty candidates_for(segment(0.0, 5.0, "  café   au lait "))
  end

  test "case and punctuation are a difference" do
    place(@entries[0], 0.0, 5.0, "current text")
    candidate = candidates_for(segment(0.0, 5.0, "Current text.")).sole
    assert candidate.differs?
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

  test "sharing half the time they cover together or less is not a match" do
    place(@entries[0], 0.0, 4.0, "current text")
    assert candidates_for(segment(2.5, 8.0, "fresh text")).sole.new_segment?
    assert candidates_for(segment(0.0, 8.0, "fresh text")).sole.new_segment?
  end

  test "sharing more than half the time they cover together is a match" do
    entry = place(@entries[0], 0.0, 4.0, "current text")
    assert_equal entry, candidates_for(segment(0.5, 4.5, "fresh text")).sole.dictionary_entry
  end

  test "a short fragment inside a long entry does not claim it" do
    place(@entries[0], 0.0, 10.0, "current long text")
    assert candidates_for(segment(4.0, 4.5, "word")).sole.new_segment?
  end

  test "a short interjection inside a long turn matches its own entry, not the turn" do
    turn = place(@entries[0], 0.0, 10.0, "long turn")
    interjection = place(@entries[1], 4.0, 4.6, "yes")

    assert_empty candidates_for(segment(0.0, 10.0, "long turn"), segment(4.0, 4.6, "yes", speaker: "SPEAKER_01"))

    candidates = candidates_for(segment(0.1, 10.0, "long turn changed"), segment(4.05, 4.6, "yes changed", speaker: "SPEAKER_01"))
    assert_equal [turn, interjection], candidates.map(&:dictionary_entry)
    assert candidates.all?(&:differs?)
  end

  test "a brief segment across two neighbours leaves both matches alone" do
    place(@entries[0], 0.0, 5.0, "first")
    place(@entries[1], 5.0, 10.0, "second")
    candidate = candidates_for(segment(0.0, 5.0, "first"), segment(4.9, 5.1, "blip"), segment(5.0, 10.0, "second")).sole

    assert candidate.new_segment?
    assert_equal "blip", candidate.word_or_phrase
  end

  test "an uneven split is listed as new segments, not guessed at" do
    place(@entries[0], 0.0, 10.0, "one to ten")
    candidates = candidates_for(segment(0.0, 6.0, "one to six"), segment(6.0, 10.0, "seven to ten"))

    assert candidates.all?(&:new_segment?)
  end

  test "an uneven merge is listed as a new segment, not guessed at" do
    place(@entries[0], 0.0, 6.0, "one to three")
    place(@entries[1], 6.0, 10.0, "four and five")

    assert candidates_for(segment(0.0, 10.0, "one to five")).sole.new_segment?
  end

  test "a sliver left over at the edge of an entry does not stop the match" do
    entry = place(@entries[0], 0.0, 10.0, "current long text")
    candidates = candidates_for(segment(0.0, 8.5, "most of it"), segment(8.5, 10.0, "tail"))

    assert_equal [entry, nil], candidates.map(&:dictionary_entry)
  end

  test "two speakers over the same span are not paired up crosswise" do
    place(@entries[0], 0.0, 5.0, "alpha")
    place(@entries[1], 0.0, 5.0, "bravo")
    candidates = candidates_for(segment(0.0, 5.0, "bravo", speaker: "SPEAKER_01"), segment(0.0, 5.0, "alpha"))

    assert candidates.none?(&:differs?)
  end

  test "a segment over no entry is a new segment" do
    place(@entries[0], 0.0, 5.0, "current text")
    candidate = candidates_for(segment(0.0, 5.0, "current text"), segment(30.0, 34.0, "something new", id: "s9", speaker: "SPEAKER_02")).sole

    assert candidate.new_segment?
    assert_nil candidate.dictionary_entry
    assert_equal ["s9", "SPEAKER_02", 30.0, 34.0], [candidate.region_id, candidate.speaker_label, candidate.region_start, candidate.region_end]
  end

  test "an entry split into two segments is listed as new segments, not guessed at" do
    place(@entries[0], 0.0, 10.0, "current long text")
    candidates = candidates_for(segment(0.0, 5.0, "first half"), segment(5.0, 10.0, "second half"))

    assert_equal %w[first\ half second\ half], candidates.map(&:word_or_phrase)
    assert candidates.all?(&:new_segment?)
  end

  test "two entries merged into one segment is listed as a new segment, not guessed at" do
    place(@entries[0], 0.0, 5.0, "first half")
    place(@entries[1], 5.0, 10.0, "second half")
    candidate = candidates_for(segment(0.0, 10.0, "first half second half")).sole

    assert candidate.new_segment?
  end

  test "a split next to a clean match leaves the clean match alone" do
    place(@entries[0], 0.0, 10.0, "current long text")
    clean = place(@entries[1], 10.0, 15.0, "current text")
    candidates = candidates_for(segment(0.0, 5.0, "first half"), segment(5.0, 10.0, "second half"), segment(10.0, 15.0, "fresh text"))

    assert_equal [:new_segment, :new_segment, :differs], candidates.map { |c| c.kind.to_sym }
    assert_equal clean, candidates.last.dictionary_entry
  end

  test "a confirmed entry still gets its candidate, for the review to show read-only" do
    entry = place(@entries[1], 0.0, 5.0, "current text", accuracy_status: DictionaryEntry.accuracy_statuses[:confirmed])
    candidate = candidates_for(segment(0.0, 5.0, "fresh text")).sole

    assert entry.reload.confirmed?
    assert_equal entry, candidate.dictionary_entry
    assert candidate.differs?
  end

  test "entries no segment lines up with are left alone" do
    place(@entries[0], 0.0, 5.0, "current text")
    place(@entries[1], 40.0, 45.0, "untouched")
    assert_equal ["fresh text"], candidates_for(segment(0.0, 5.0, "fresh text")).map(&:word_or_phrase)
  end

  test "entries without a span, and entries from other recordings, are not matched" do
    place(@entries[0], 0.0, 5.0, "no span").update_columns(region_start: nil, region_end: nil)
    place(@entries[1], 0.0, 5.0, "elsewhere").update_columns(voice_recording_id: voice_recordings(:one).id)
    candidate = candidates_for(segment(0.0, 5.0, "fresh text")).sole

    assert candidate.new_segment?
  end

  test "segments missing timings or text, or running backwards, are skipped" do
    candidates = candidates_for(
      segment(0.0, 5.0, "kept"),
      segment("1.5", "2.5", "kept from strings"),
      segment("", 5.0, "blank start"),
      segment("abc", 5.0, "garbled start"),
      segment(nil, 5.0, "no start"),
      segment(1.0, nil, "no end"),
      segment(6.0, 6.0, "no length"),
      segment(8.0, 7.0, "backwards"),
      segment(-1.0, 2.0, "negative"),
      segment(9.0, 10.0, "  "),
      "not a segment"
    )

    assert_equal ["kept", "kept from strings"], candidates.map(&:word_or_phrase)
  end

  test "an empty run has no candidates" do
    place(@entries[0], 0.0, 5.0, "current text")
    assert_empty candidates_for
  end

  test "candidates come back in time order and are valid" do
    place(@entries[0], 20.0, 25.0, "current text")
    candidates = candidates_for(segment(20.0, 25.0, "fresh text"), segment(2.0, 4.0, "early"))

    assert_equal [2.0, 20.0], candidates.map(&:region_start)
    assert candidates.all?(&:valid?), candidates.map { |c| c.errors.full_messages }.inspect
  end

  test "building candidates saves nothing" do
    place(@entries[0], 0.0, 5.0, "current text")
    assert_no_difference "TranscriptionCandidate.count" do
      candidates_for(segment(0.0, 5.0, "fresh text"))
    end
  end

  test "call saves the candidates against the run" do
    place(@entries[0], 0.0, 5.0, "current text")
    @run.update!(segments: [segment(0.0, 5.0, "fresh text"), segment(30.0, 34.0, "something new")])

    saved = Transcription::MatchCandidates.call(@run)

    assert_equal 2, saved.size
    assert saved.all?(&:persisted?)
    assert_equal saved.sort_by(&:id), @run.transcription_candidates.order(:id).to_a
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
    entries = [place(@entries[0], 0.0, 5.0, "current text"), place(@entries[1], 5.0, 10.0, "next text")]
    before = entries.map { |e| e.reload.attributes.slice("word_or_phrase", "translation", "accuracy_status", "updated_at") }
    recording_before = @recording.reload.diarization_data
    @run.update!(segments: [segment(0.0, 5.0, "fresh text"), segment(5.0, 10.0, "other text"), segment(30.0, 34.0, "new")])

    assert_no_difference ["PaperTrail::Version.count", "DictionaryEntry.count"] do
      assert_equal 3, Transcription::MatchCandidates.call(@run).size
    end
    assert_equal before, entries.map { |e| e.reload.attributes.slice("word_or_phrase", "translation", "accuracy_status", "updated_at") }
    assert_equal recording_before, @recording.reload.diarization_data
  end

  # Real Fotheidil timings (395 segments, speakers overlapping), with the
  # text replaced by placeholders.
  def real_timings
    JSON.parse(file_fixture("fotheidil_video_1141_segments.json").read).each_with_index.map do |raw, i|
      raw.slice("id", "speaker", "startTimeSeconds", "endTimeSeconds").merge("text" => "line #{i}")
    end
  end

  def place_entries_for(timings)
    rows = timings.map do |raw|
      {voice_recording_id: @recording.id, speaker_id: @entries[0].speaker_id, user_id: @entries[0].user_id,
       region_start: raw["startTimeSeconds"], region_end: raw["endTimeSeconds"], region_id: raw["id"],
       word_or_phrase: raw["text"], created_at: Time.current, updated_at: Time.current}
    end
    DictionaryEntry.insert_all!(rows)
  end

  test "re-running a real recording with the same output finds nothing to review" do
    timings = real_timings
    place_entries_for(timings)
    assert_empty candidates_for(*timings)
  end

  test "re-running a real recording with every line changed lines each up with its own entry" do
    timings = real_timings
    place_entries_for(timings)
    candidates = candidates_for(*timings.map { |raw| raw.merge("text" => "#{raw["text"]} changed") })

    assert_equal timings.size, candidates.size
    assert candidates.all?(&:differs?)
    assert_equal timings.pluck("id"), candidates.map { |c| c.dictionary_entry.region_id }
  end

  test "small boundary shifts on a real recording still line up nearly everything" do
    timings = real_timings
    place_entries_for(timings)
    random = Random.new(133)
    shifted = timings.map do |raw|
      start = [raw["startTimeSeconds"] + random.rand(-0.2..0.2), 0].max
      raw.merge("startTimeSeconds" => start, "endTimeSeconds" => [raw["endTimeSeconds"] + random.rand(-0.2..0.2), start + 0.1].max, "text" => "fresh")
    end

    candidates = candidates_for(*shifted)
    assert_operator candidates.count(&:differs?), :>=, (timings.size * 0.9).ceil
  end

  test "a real recording is matched in two queries, without a query per segment" do
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
