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
  # A form is matched as the start of a word once it is this long.
  MIN_PREFIX = 2
  # Each term becomes several forms, so only this many terms are expanded.
  MAX_FORM_TERMS = 10

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

    expanded = terms.first(MAX_FORM_TERMS)
    expanded.map.with_index { |term, index| any_form(term, prefix: index == expanded.size - 1) }.join(" AND ")
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
    irish = mutations.forms(term).map { |form| quoted(form, prefix:) }.join(" OR ")
    %[(#{IRISH} : (#{irish}) OR #{ENGLISH} : #{quoted(term, prefix:)})]
  end

  # A one-letter prefix would match almost every line, so it stays a whole word.
  def quoted(text, prefix:)
    star = (prefix && text.unicode_normalize(:nfc).length >= MIN_PREFIX) ? "*" : ""
    %("#{text}"#{star})
  end
end
