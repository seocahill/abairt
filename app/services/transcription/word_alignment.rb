# frozen_string_literal: true

module Transcription
  # Lines up two lists of words in order, so each word on one side is either
  # paired with a word on the other or left over (#133). Words are lined up on
  # their keys; a stretch where both sides have different words is paired word
  # for word, which suits a line that has been corrected.
  #
  #   WordAlignment.new(%w[a b c], %w[a x c d]).pairs
  #   # => pairs 0-0 (exact), 1-1 (different), 2-2 (exact); "d" is left over
  #
  # It is a longest common subsequence over the whole of both lists, so keep
  # the lists to one stretch of a recording, not a whole day of talk.
  class WordAlignment
    # Slower than a person can read; anything longer is a mistake to catch.
    MAX_WORDS = 20_000

    class TooLong < StandardError; end

    Pair = Data.define(:left, :right, :exact) do
      alias_method :exact?, :exact
    end

    def initialize(left, right)
      @left = left
      @right = right
      raise TooLong, "Too many words to line up (#{left.size} and #{right.size})" if [left.size, right.size].max > MAX_WORDS
    end

    def pairs
      Diff::LCS.sdiff(@left, @right).filter_map do |change|
        next if change.action == "-" || change.action == "+"

        Pair.new(left: change.old_position, right: change.new_position, exact: change.unchanged?)
      end
    end
  end
end
