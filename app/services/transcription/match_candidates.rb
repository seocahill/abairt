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
  # A segment and an entry line up when:
  # - they share more than half of the time they cover together (overlap over
  #   union), so a short interjection inside a long turn (common in Fotheidil
  #   output, where speakers overlap) doesn't claim the long entry;
  # - each is the other's best overlap (identical text wins a tie);
  # - neither has a rival: another segment lying mostly inside the entry,
  #   covering more than a fifth of it and lining up with nothing better (a
  #   split), or the same the other way round (a merge). Splits and merges are
  #   listed as new segments rather than guessed at; someone talking over a
  #   turn has their own entry and is no rival.
  #
  # Entries no segment lines up with are left alone. Nothing here writes to an
  # entry, its translation or the recording.
  #
  #   Transcription::MatchCandidates.new(run).candidates  # unsaved, to inspect
  #   Transcription::MatchCandidates.call(run)             # saves them
  class MatchCandidates
    MIN_SHARED = 0.5
    RIVAL_COVERAGE = 0.2

    # The time a segment and an entry have in common, both by index.
    Overlap = Data.define(:segment, :entry, :seconds, :segment_length, :entry_length) do
      def shared = seconds / (segment_length + entry_length - seconds)

      def of_segment = seconds / segment_length

      def of_entry = seconds / entry_length

      # This entry is a second piece within the segment (a merge).
      def merges? = of_entry > MIN_SHARED && of_segment > RIVAL_COVERAGE

      # This segment is a second piece within the entry (a split).
      def splits? = of_segment > MIN_SHARED && of_entry > RIVAL_COVERAGE
    end

    def self.call(run)
      new(run).call
    end

    def initialize(run)
      @run = run
    end

    # Saves the candidates once, under a lock on the run (so save the run's
    # segments first). A run that already has candidates keeps them, so
    # calling it again never duplicates or resets a person's decisions.
    def call
      @run.with_lock do
        next @run.transcription_candidates.to_a if @run.transcription_candidates.exists?

        candidates.each(&:save!)
      end
    end

    def candidates
      segments.each_with_index.filter_map do |segment, index|
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

    # segment index => entry, for the clean one-to-one pairs.
    def matches
      @matches ||= overlaps.select { |o| clean?(o) }.to_h { |o| [o.segment, entries[o.entry]] }
    end

    def clean?(overlap)
      overlap.shared > MIN_SHARED &&
        best_for_segment[overlap.segment] == overlap &&
        best_for_entry[overlap.entry] == overlap &&
        by_segment[overlap.segment].none? { |o| merged_in?(o, overlap) } &&
        by_entry[overlap.entry].none? { |o| split_off?(o, overlap) }
    end

    # Another entry lies mostly inside the segment and has no better segment:
    # the segment merges it with the match.
    def merged_in?(other, overlap)
      other != overlap && other.merges? && best_for_entry[other.entry].segment == overlap.segment
    end

    # Another segment lies mostly inside the entry and has no better entry: the
    # entry was split between them. A segment from someone talking over the
    # entry has its own entry and isn't a split.
    def split_off?(other, overlap)
      other != overlap && other.splits? && best_for_segment[other.segment].entry == overlap.entry
    end

    def best(overlaps)
      overlaps.max_by { |o| [o.shared, same_text?(entries[o.entry].word_or_phrase, segments[o.segment]["text"]) ? 1 : 0] }
    end

    def best_for_segment
      @best_for_segment ||= by_segment.transform_values { |group| best(group) }
    end

    def best_for_entry
      @best_for_entry ||= by_entry.transform_values { |group| best(group) }
    end

    def by_segment
      @by_segment ||= overlaps.group_by(&:segment)
    end

    def by_entry
      @by_entry ||= overlaps.group_by(&:entry)
    end

    # Every segment-entry pair with time in common. Entries are sorted by
    # start, so only those starting within the longest entry's length before a
    # segment ends can overlap it.
    def overlaps
      @overlaps ||= segments.each_with_index.flat_map do |segment, index|
        nearby_entries(segment).filter_map { |entry| overlap(segment, index, entry) }
      end
    end

    def overlap(segment, index, entry)
      entry_start, entry_end = entry_spans[entry]
      seconds = [segment["finish"], entry_end].min - [segment["start"], entry_start].max
      return unless seconds.positive?

      Overlap.new(segment: index, entry:, seconds:, segment_length: segment["finish"] - segment["start"], entry_length: entry_end - entry_start)
    end

    def nearby_entries(segment)
      first = entry_starts.bsearch_index { |start| start > segment["start"] - longest_entry } || entry_starts.size
      last = entry_starts.bsearch_index { |start| start >= segment["finish"] } || entry_starts.size
      (first...last)
    end

    def entry_spans
      @entry_spans ||= entries.map { |entry| [entry.region_start.to_f, entry.region_end.to_f] }
    end

    def entry_starts
      @entry_starts ||= entry_spans.map(&:first)
    end

    def longest_entry
      @longest_entry ||= entry_spans.map { |start, finish| finish - start }.max.to_f
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
