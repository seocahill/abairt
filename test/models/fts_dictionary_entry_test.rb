require "test_helper"

class FtsDictionaryEntryTest < ActiveSupport::TestCase

  setup do
    ActiveRecord::Base.connection.execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase
      FROM dictionary_entries;
    SQL
  end

  test "search" do
    query = dictionary_entries(:one).word_or_phrase
    assert_equal FtsDictionaryEntry.where("fts_dictionary_entries match ?", query).first.word_or_phrase, dictionary_entries(:one).word_or_phrase
  end
end
