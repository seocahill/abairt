# frozen_string_literal: true

module Transcription
  # Lines up a transcription run's fresh text with the recording's current
  # entries (#133) and keeps what a person needs to review as candidates.
  #
  # The two are compared word by word, not segment by segment (see Grouping
  # and GroupMatch), so a text that was typed in, copied from elsewhere, or
  # cut into lines differently still lines up. For each current entry:
  #
  # - `differs`: the new text for the entry says something different;
  # - `timing`: the entry has no times and the new transcription says where
  #   it is spoken, so a person can give it times (its text stays as it is);
  # - nothing: it says the same, or nothing in the new transcription lines up
  #   with it. The second is kept on the run as `unheard_entry_ids`, so a
  #   person can see it.
  #
  # New text that no entry accounts for becomes a `new_segment` candidate.
  # Nothing here writes to an entry, its translation or the recording.
  #
  #   Transcription::MatchCandidates.new(run).candidates       # unsaved, to inspect
  #   Transcription::MatchCandidates.new(run).unheard_entries  # current lines not heard
  #   Transcription::MatchCandidates.call(run)                 # saves them
  class MatchCandidates
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

        candidates.each(&:save!).tap { @run.update!(unheard_entry_ids: unheard_entries.map(&:id)) }
      end
    end

    def candidates
      @candidates ||= matches.flat_map { |match| candidates_for(match) }.sort_by { |candidate| [candidate.region_start, candidate.kind] }
    end

    def unheard_entries
      @unheard_entries ||= matches.flat_map(&:unheard)
    end

    private

    def matches
      @matches ||= groups.map { |group| GroupMatch.new(group.entries, group.segments, timed: group.timed).call }
    end

    def groups
      Grouping.new(@run.voice_recording.dictionary_entries.to_a, segments).groups
    end

    def segments
      @segments ||= Heard.new(@run.segments).segments
    end

    def candidates_for(match)
      match.lines.flat_map { |line| line_candidates(line) } +
        match.leftovers.map { |words| build(words, kind: :new_segment) }
    end

    def line_candidates(line)
      entry = line.entry
      candidates = []
      candidates << build(line.words, kind: :differs, dictionary_entry: entry) unless Text.same?(entry.word_or_phrase, text_of(line.words))
      candidates << build(line.aligned, kind: :timing, dictionary_entry: entry, word_or_phrase: entry.word_or_phrase) if entry.region_start.nil?
      candidates
    end

    def build(words, **attrs)
      segment = segments[words.first.segment]
      TranscriptionCandidate.new(
        transcription_run: @run,
        region_start: words.first.start,
        region_end: words.last.finish,
        region_id: segment.id,
        speaker_label: segment.speaker,
        word_or_phrase: text_of(words),
        **attrs
      )
    end

    def text_of(words)
      words.map(&:text).join(" ")
    end
  end
end
