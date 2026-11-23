# frozen_string_literal: true

module Transcription
  # Lines up the text of some entries with the words of some segments, word by
  # word and over the whole stretch (#133), so it does not matter where one
  # line ends and the next begins. For each entry it finds the words that
  # correspond to it:
  #
  # - `aligned`: the words lined up with the entry's own words;
  # - `words`: those, and the rest of the segments they sit in, so a line is
  #   not left with the end of a sentence cut off.
  #
  # An entry nothing lines up with is `unheard`. Words no entry claims are
  # `leftovers`, in pieces of one segment each.
  #
  # With `timed: false` the entries have no times to check the match against,
  # so an entry must share at least a third of its words with what it is lined
  # up with, or it counts as unheard and its words as left over. A text that
  # was copied in and then reworded still lines up; a different text doesn't.
  class GroupMatch
    MIN_EXACT = 0.3

    Line = Data.define(:entry, :aligned, :words, :span)
    Outcome = Data.define(:lines, :leftovers, :unheard)

    def initialize(entries, segments, timed:)
      @entries = entries
      @heard = segments.flat_map(&:words)
      @timed = timed
    end

    def call
      Outcome.new(lines:, leftovers:, unheard:)
    end

    private

    # [entry index, word] for every word of every entry.
    def written
      @written ||= @entries.each_with_index.flat_map { |entry, index| Text.words(entry.word_or_phrase).map { |word| [index, word] } }
    end

    def counts
      @counts ||= written.map(&:first).tally
    end

    def pairs_by_entry
      @pairs_by_entry ||= WordAlignment.new(written.map { |_, word| Text.key(word) }, @heard.map(&:key))
        .pairs.group_by { |pair| written[pair.left].first }
    end

    # Entry index => the pairs that tie it to the heard words, for the
    # entries that are matched.
    def matched
      @matched ||= pairs_by_entry.select { |index, pairs| @timed || pairs.count(&:exact?) >= MIN_EXACT * counts[index] }
    end

    def lines
      @lines ||= begin
        bounds = matched.map { |index, pairs| [index, pairs.minmax_by(&:right).map(&:right)] }
        floor = -1
        bounds.each_with_index.map do |(index, (first, last)), position|
          from = grow_back(first, floor)
          to = grow_forward(last, bounds[position + 1]&.last&.first || @heard.size)
          floor = to
          Line.new(entry: @entries[index], aligned: @heard[first..last], words: @heard[from..to], span: from..to)
        end
      end
    end

    # A segment's other words go with the entry that has part of it, as far
    # as the neighbouring entry's words allow.
    def grow_forward(last, ceiling)
      last += 1 while last + 1 < ceiling && @heard[last + 1].segment == @heard[last].segment
      last
    end

    def grow_back(first, floor)
      first -= 1 while first - 1 > floor && @heard[first - 1].segment == @heard[first].segment
      first
    end

    def leftovers
      unclaimed = (0...@heard.size).to_a - lines.flat_map { |line| line.span.to_a }
      unclaimed
        .slice_when { |before, after| after != before + 1 || @heard[before].segment != @heard[after].segment }
        .map { |piece| @heard.values_at(*piece) }
    end

    def unheard
      @entries.each_index.reject { |index| matched.key?(index) || !counts.key?(index) }.map { |index| @entries[index] }
    end
  end
end
