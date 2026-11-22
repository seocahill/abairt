# frozen_string_literal: true

# Turns whatever a person typed into a safe SQLite FTS5 expression.
# FTS5 treats punctuation and words like AND/NOT as query syntax, so every term is
# reduced to letters and digits and quoted. Hyphens and apostrophes split terms.
#
#   DictionarySearch.new("sean-bhean?").expression  # => "\"sean\" \"bhean\""
#   DictionarySearch.new("bean").expression(forms: true)
#   # => "(word_or_phrase : (\"bean\"* OR \"bhean\"* OR \"mbean\"*) OR translation : \"bean\"*)"
#   DictionarySearch.new("a bhean").phrase_expression(column: :word_or_phrase)
#   # => "word_or_phrase : \"a bhean\""
class DictionarySearch
  IRISH = :word_or_phrase
  ENGLISH = :translation
  # The last term is matched as the start of a word once it is this long.
  MIN_PREFIX = 2

  def initialize(text)
    @terms = text.to_s.scan(/[\p{L}\p{M}\p{N}]+/)
  end

  def blank?
    terms.empty?
  end

  # All terms must match, in any order. With forms: true (flag f171) each term
  # also matches its mutated spellings in the Irish, and the last term matches
  # the start of a word, so a half-typed word finds the whole one.
  def expression(forms: false)
    return terms.map { |term| %("#{term}") }.join(" ") unless forms

    terms.map.with_index { |term, index| any_form(term, prefix: index == terms.size - 1) }.join(" AND ")
  end

  # The terms must appear together, in order, optionally within one column.
  def phrase_expression(column: nil)
    phrase = %("#{terms.join(" ")}")
    column ? "#{column} : #{phrase}" : phrase
  end

  private

  attr_reader :terms

  def mutations
    @mutations ||= IrishMutations.new
  end

  def any_form(term, prefix:)
    star = (prefix && term.length >= MIN_PREFIX) ? "*" : ""
    irish = mutations.forms(term).map { |form| %("#{form}"#{star}) }.join(" OR ")
    %[(#{IRISH} : (#{irish}) OR #{ENGLISH} : "#{term}"#{star})]
  end
end
