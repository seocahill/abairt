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
end
