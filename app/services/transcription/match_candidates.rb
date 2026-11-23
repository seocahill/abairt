# frozen_string_literal: true

module Transcription
  # Lines up a transcription run's fresh segments with the recording's current
  # entries (#133) and keeps what a person needs to review as candidates:
  #
  # - a segment that lines up with an entry and says something different is a
  #   `differs` candidate for that entry;
  # - a segment that lines up with no entry is a `new_segment` candidate;
  # - a segment that lines up with an entry and says the same thing is left out.
  #
  # A segment and an entry line up when each is the other's best overlap and
  # they share more than half of the time they cover together (overlap over
  # union). Measuring against the union rather than the shorter span keeps a
  # short interjection inside a long turn (common in Fotheidil output, where
  # speakers overlap) from claiming the long entry, and means an even split or
  # merge has no clean match and is listed as new segments rather than guessed
  # at. Entries no segment lines up with are left alone.
  #
  # Nothing here writes to an entry, its translation or the recording.
  #
  #   Transcription::MatchCandidates.new(run).candidates  # unsaved, to inspect
  #   Transcription::MatchCandidates.call(run)             # saves them
  class MatchCandidates
    MIN_SHARED = 0.5

    Span = Data.define(:start, :finish) do
      def length = finish - start

      def shared_with(other)
        overlap = [finish, other.finish].min - [start, other.start].max
        return 0.0 unless overlap.positive?

        overlap / ([finish, other.finish].max - [start, other.start].min)
      end
    end

    def self.call(run)
      new(run).call
    end

    def initialize(run)
      @run = run
    end

    # Saves the candidates once, under a lock on the run. A run that already
    # has candidates keeps them, so calling it again never duplicates or resets
    # a person's decisions.
    def call
      @run.with_lock do
        next @run.transcription_candidates.to_a if @run.transcription_candidates.exists?

        candidates.each(&:save!)
      end
    end

    def candidates
      segments.each_index.filter_map do |index|
        segment = segments[index]
        entry = matches[index]
        next build(segment, kind: :new_segment) if entry.nil?
        next if same_text?(entry.word_or_phrase, segment["text"])

        build(segment, kind: :differs, dictionary_entry: entry)
      end
    end

    private

    def segments
      @segments ||= Array(@run.segments).filter_map { |raw| usable(raw) }.sort_by { |s| [s["start"], s["finish"]] }
    end

    def usable(raw)
      return unless raw.is_a?(Hash)

      start = Float(raw["startTimeSeconds"], exception: false)
      finish = Float(raw["endTimeSeconds"], exception: false)
      text = raw["text"].to_s.strip
      return if start.nil? || finish.nil? || start.negative? || finish <= start || text.empty?

      raw.merge("start" => start, "finish" => finish, "text" => text)
    end

    def entries
      @entries ||= @run.voice_recording.dictionary_entries
        .where.not(region_start: nil).where.not(region_end: nil)
        .where("region_end > region_start")
        .order(:region_start, :id)
        .to_a
    end

    def entry_spans
      @entry_spans ||= entries.map { |entry| Span.new(entry.region_start.to_f, entry.region_end.to_f) }
    end

    def segment_span(index)
      Span.new(segments[index]["start"], segments[index]["finish"])
    end

    # segment index => entry, for pairs that are each other's best overlap.
    def matches
      @matches ||= best_entry_for_segment.select { |segment, entry| best_segment_for_entry[entry] == segment }
        .transform_values { |entry| entries[entry] }
    end

    def best_entry_for_segment
      @best_entry_for_segment ||= shared.group_by(&:first).transform_values { |pairs| pairs.max_by(&:last)[1] }
    end

    def best_segment_for_entry
      @best_segment_for_entry ||= shared.group_by { |pair| pair[1] }.transform_values { |pairs| pairs.max_by(&:last).first }
    end

    # [segment index, entry index, share] for every pair sharing enough time.
    # Entries are sorted by start, so only those starting within the longest
    # entry's length before a segment ends can overlap it.
    def shared
      @shared ||= segments.each_index.flat_map do |index|
        span = segment_span(index)
        nearby_entries(span).filter_map do |entry|
          share = span.shared_with(entry_spans[entry])
          [index, entry, share] if share > MIN_SHARED
        end
      end
    end

    def nearby_entries(span)
      first = entry_starts.bsearch_index { |start| start > span.start - longest_entry } || entry_starts.size
      last = entry_starts.bsearch_index { |start| start >= span.finish } || entry_starts.size
      (first...last)
    end

    def entry_starts
      @entry_starts ||= entry_spans.map(&:start)
    end

    def longest_entry
      @longest_entry ||= entry_spans.map(&:length).max.to_f
    end

    # Whitespace and how a fada is encoded don't count as a difference;
    # anything a reader could see (letters, case, punctuation) does.
    def same_text?(current, fresh)
      comparable(current) == comparable(fresh)
    end

    def comparable(text)
      text.to_s.unicode_normalize(:nfc).squish
    end

    def build(segment, **attrs)
      TranscriptionCandidate.new(
        transcription_run: @run,
        region_start: segment["start"],
        region_end: segment["finish"],
        region_id: segment["id"]&.to_s,
        speaker_label: segment["speaker"],
        word_or_phrase: segment["text"],
        **attrs
      )
    end
  end
end
