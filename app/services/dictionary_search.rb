# frozen_string_literal: true

# Turns whatever a person typed into a safe SQLite FTS5 expression.
# FTS5 treats punctuation and words like AND/NOT as query syntax, so every term is
# reduced to letters and digits and quoted. Hyphens and apostrophes split terms.
#
#   DictionarySearch.new("sean-bhean?").expression  # => "\"sean\" \"bhean\""
#   DictionarySearch.new("a bhean").phrase_expression(column: :word_or_phrase)
#   # => "word_or_phrase : \"a bhean\""
class DictionarySearch
  def initialize(text)
    @terms = text.to_s.scan(/[\p{L}\p{N}]+/)
  end

  def blank?
    terms.empty?
  end

  # All terms must match, in any order.
  def expression
    terms.map { |term| %("#{term}") }.join(" ")
  end

  # The terms must appear together, in order, optionally within one column.
  def phrase_expression(column: nil)
    phrase = %("#{terms.join(" ")}")
    column ? "#{column} : #{phrase}" : phrase
  end

  private

  attr_reader :terms
end
