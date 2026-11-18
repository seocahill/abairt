require "test_helper"

class DictionaryEntrySearchTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase FROM dictionary_entries;
    SQL
    @entry = dictionary_entries(:one)
  end

  test "search finds an entry by its words" do
    assert_includes DictionaryEntry.search(@entry.word_or_phrase), @entry
  end

  ["bhean.", "a bhean?", "sean-bhean", '"bhean', "AND", "NOT bean", "(", "*"].each do |typed|
    test "search never raises for #{typed.inspect}" do
      assert_nothing_raised { DictionaryEntry.search(typed).to_a }
      assert_nothing_raised { DictionaryEntry.matching_irish(typed).to_a }
    end
  end

  test "search with only punctuation or nothing returns no entries" do
    assert_empty DictionaryEntry.search("?!")
    assert_empty DictionaryEntry.search(nil)
    assert_empty DictionaryEntry.matching_irish("")
  end

  test "search tolerates punctuation around a real word" do
    assert_includes DictionaryEntry.search("#{@entry.word_or_phrase}?"), @entry
  end
end
