# frozen_string_literal: true

module Asr
  # Folds a transcript so two versions can be compared: NFC (fadas survive as
  # single characters), lower case, punctuation removed. Apostrophes and
  # hyphens stay, and nothing is done to lenition or eclipsis, so a mutation
  # difference counts as an error.
  class Normaliser
    APOSTROPHES = /[‘’ʼ]/

    def self.call(text)
      text.to_s
        .unicode_normalize(:nfc)
        .downcase
        .gsub(APOSTROPHES, "'")
        .gsub(/[^\p{L}\p{M}\p{N}'\-\s]/u, " ")
        .split.map { |w| w.gsub(/\A[-']+|[-']+\z/, "") }.reject(&:empty?).join(" ")
    end
  end
end
