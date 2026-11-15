# frozen_string_literal: true

module Asr
  # Word and character error rates for one reference/hypothesis pair.
  # Returns the edit counts, not just the rate, so they can be summed across a
  # group (a speaker, a dialect) before dividing.
  class ErrorRate
    Result = Struct.new(:word_errors, :word_total, :char_errors, :char_total)

    def self.call(reference, hypothesis)
      ref = Normaliser.call(reference)
      hyp = Normaliser.call(hypothesis)

      Result.new(
        distance(ref.split, hyp.split), ref.split.size,
        distance(ref.delete(" ").chars, hyp.delete(" ").chars), ref.delete(" ").size
      )
    end

    # Levenshtein distance between two token arrays.
    def self.distance(ref, hyp)
      return hyp.size if ref.empty?
      return ref.size if hyp.empty?

      previous = (0..hyp.size).to_a
      ref.each_with_index do |r, i|
        current = [i + 1]
        hyp.each_with_index do |h, j|
          current << [previous[j + 1] + 1, current[j] + 1, previous[j] + ((r == h) ? 0 : 1)].min
        end
        previous = current
      end
      previous.last
    end
  end
end
