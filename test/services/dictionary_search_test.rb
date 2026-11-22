require "test_helper"

class DictionarySearchTest < ActiveSupport::TestCase
  test "quotes each term so punctuation is literal" do
    assert_equal '"bhean"', DictionarySearch.new("bhean.").expression
    assert_equal '"a" "bhean"', DictionarySearch.new("a bhean?").expression
    assert_equal '"bhean"', DictionarySearch.new('"bhean').expression
  end

  test "hyphens and apostrophes split terms" do
    assert_equal '"sean" "bhean"', DictionarySearch.new("sean-bhean").expression
    assert_equal '"an" "t" "uisce"', DictionarySearch.new("an t-uisce").expression
  end

  test "operator words are quoted" do
    assert_equal '"AND" "NOT"', DictionarySearch.new("AND NOT").expression
  end

  test "keeps accented letters" do
    assert_equal '"fáilte"', DictionarySearch.new("fáilte!").expression
  end

  test "decomposed accents stay in one term" do
    assert_equal %("fa\u0301ilte"), DictionarySearch.new("fa\u0301ilte").expression
  end

  test "blank for empty or punctuation-only text" do
    assert DictionarySearch.new(nil).blank?
    assert DictionarySearch.new("  ?! ").blank?
    assert_not DictionarySearch.new("bean").blank?
  end

  test "phrase expression scopes to a column" do
    assert_equal 'word_or_phrase : "a bhean"', DictionarySearch.new("a bhean.").phrase_expression(column: :word_or_phrase)
    assert_equal '"a bhean"', DictionarySearch.new("a bhean").phrase_expression
  end

  test "with forms, each term matches its mutated spellings in the Irish and itself in the English" do
    assert_equal '(word_or_phrase : ("mo" OR "mho") OR translation : "mo") AND ' \
      '(word_or_phrase : ("bean"* OR "bhean"* OR "mbean"*) OR translation : "bean"*)',
      DictionarySearch.new("mo bean").expression(forms: true)
  end

  test "with forms, only the last term matches the start of a word" do
    expression = DictionarySearch.new("bean fear").expression(forms: true)

    assert_includes expression, '"bean" OR'
    assert_includes expression, '"fear"*'
  end

  test "with forms, a one-letter last term is not a prefix" do
    assert_equal '(word_or_phrase : ("a") OR translation : "a")', DictionarySearch.new("a").expression(forms: true)
  end

  test "with forms, punctuation is still literal" do
    assert_equal DictionarySearch.new("bhean").expression(forms: true), DictionarySearch.new("bhean?!").expression(forms: true)
    assert_not_includes DictionarySearch.new('"AND').expression(forms: true), '""'
  end

  test "with forms, a short word does not turn into a one-letter prefix" do
    assert_equal '(word_or_phrase : ("tá"* OR "thá"* OR "dtá"*) OR translation : "tá"*)',
      DictionarySearch.new("tá").expression(forms: true)
    assert_not_includes DictionarySearch.new("nó").expression(forms: true), '"ó"'
  end

  test "with forms, only the first ten words are expanded" do
    expression = DictionarySearch.new((%w[bean] * 15).join(" ")).expression(forms: true)

    assert_equal DictionarySearch::MAX_FORM_TERMS, expression.scan("word_or_phrase :").size
  end
end
