# frozen_string_literal: true

module Transcription
  # Lines up a transcription run's fresh segments with the recording's current
  # entries (#133) and keeps what a person needs to review as candidates:
  #
  # - a segment that lines up with one entry and says something different is a
  #   `differs` candidate for that entry;
  # - a segment that lines up with no entry, or not cleanly, is a `new_segment`
  #   candidate;
  # - a segment that lines up with an entry and says the same thing is left out.
  #
  # "Lines up" means time overlap of at least half the shorter of the two
  # spans. Only one-to-one matches count: when an entry overlaps several
  # segments (a split) or a segment overlaps several entries (a merge), those
  # segments are listed as new rather than guessed at. Entries no segment lines
  # up with are left alone.
  #
  # Nothing here writes to an entry, its translation or the recording.
  #
  #   Transcription::MatchCandidates.new(run).candidates  # unsaved, to inspect
  #   Transcription::MatchCandidates.call(run)             # saves them
  class MatchCandidates
    MIN_OVERLAP = 0.5

    Segment = Data.define(:region_id, :start, :finish, :text, :speaker) do
      def self.from(raw)
        new(
          region_id: raw["id"]&.to_s,
          start: raw["startTimeSeconds"]&.to_f,
          finish: raw["endTimeSeconds"]&.to_f,
          text: raw["text"].to_s.strip,
          speaker: raw["speaker"]
        )
      end

      def usable?
        start.present? && finish.present? && start >= 0 && finish > start && text.present?
      end
    end

    def self.call(run)
      new(run).call
    end

    def initialize(run)
      @run = run
    end

    # Saves the candidates once. A run that already has candidates keeps them,
    # so calling it again never duplicates or resets a person's decisions.
    def call
      return @run.transcription_candidates.to_a if @run.transcription_candidates.exists?

      TranscriptionCandidate.transaction { candidates.each(&:save!) }
    end

    def candidates
      segments.filter_map do |segment|
        entry = clean_matches[segment]
        next new_segment(segment) if entry.nil?
        next if same_text?(entry.word_or_phrase, segment.text)

        build(segment, kind: :differs, dictionary_entry: entry)
      end
    end

    private

    def segments
      @segments ||= Array(@run.segments)
        .select { |raw| raw.is_a?(Hash) }
        .map { |raw| Segment.from(raw) }
        .select(&:usable?)
        .sort_by(&:start)
    end

    def entries
      @entries ||= @run.voice_recording.dictionary_entries
        .where.not(region_start: nil).where.not(region_end: nil)
        .where("region_end > region_start")
        .order(:region_start)
        .to_a
    end

    # segment => entry, for each pair that only lines up with each other.
    # Keyed by identity, so two segments that happen to be alike stay apart.
    def clean_matches
      @clean_matches ||= overlaps.each_with_object({}.compare_by_identity) do |(segment, matched), clean|
        clean[segment] = matched.first if matched.one? && segments_per_entry[matched.first] == 1
      end
    end

    def overlaps
      @overlaps ||= segments.map { |segment| [segment, entries.select { |entry| lines_up?(segment, entry) }] }
    end

    def segments_per_entry
      @segments_per_entry ||= overlaps.flat_map(&:last).tally
    end

    def lines_up?(segment, entry)
      entry_start = entry.region_start.to_f
      entry_end = entry.region_end.to_f
      overlap = [segment.finish, entry_end].min - [segment.start, entry_start].max
      return false unless overlap.positive?

      overlap / [segment.finish - segment.start, entry_end - entry_start].min >= MIN_OVERLAP
    end

    # Whitespace and how a fada is encoded don't count as a difference;
    # anything a reader could see (letters, case, punctuation) does.
    def same_text?(current, fresh)
      comparable(current) == comparable(fresh)
    end

    def comparable(text)
      text.to_s.unicode_normalize(:nfc).squish
    end

    def new_segment(segment)
      build(segment, kind: :new_segment)
    end

    def build(segment, **attrs)
      TranscriptionCandidate.new(
        transcription_run: @run,
        region_start: segment.start,
        region_end: segment.finish,
        region_id: segment.region_id,
        speaker_label: segment.speaker,
        word_or_phrase: segment.text,
        **attrs
      )
    end
  end
end
