# frozen_string_literal: true

module Transcription
  # How two lines of Irish are compared when a re-transcription is lined up
  # with the current text (#133). Nothing here changes a text.
  module Text
    module_function

    # The words of a line as written, in order. A mark standing alone (a dash,
    # a stray full stop) stays with the word before it, so no mark is lost
    # when text is put back together from words.
    def words(text)
      comparable(text).split.each_with_object([]) do |token, words|
        (key(token).empty? && words.any?) ? words.last << " #{token}" : words << +token
      end
    end

    # What a word is lined up on: its letters and digits, whatever the case or
    # punctuation. A fada is a letter, so a missing fada does not line up.
    def key(word)
      word.downcase.gsub(/[^\p{L}\p{N}]/, "")
    end

    # Whitespace and how a fada is encoded don't count as a difference;
    # anything a reader could see (letters, case, punctuation) does.
    def same?(current, fresh)
      comparable(current) == comparable(fresh)
    end

    # The two read the same but for case or punctuation.
    def cosmetic_difference?(current, fresh)
      !same?(current, fresh) && words(current).map { key(it) } == words(fresh).map { key(it) }
    end

    def comparable(text)
      text.to_s.unicode_normalize(:nfc).squish
    end
  end
end
