require "test_helper"

class SearchDictionaryEntriesToolTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.execute <<-SQL
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase FROM dictionary_entries;
    SQL
    @context = {user: users(:admin), host: "example.com"}
  end

  test "finds entries" do
    response = SearchDictionaryEntriesTool.call(query: dictionary_entries(:one).word_or_phrase, server_context: @context)
    assert_not response.error?
    assert_operator response.structured_content[:count], :>=, 1
  end

  test "punctuation in the query is not an error" do
    ["bhean.", "a bhean?", "sean-bhean", '"bhean'].each do |typed|
      response = SearchDictionaryEntriesTool.call(query: typed, server_context: @context)
      assert_not response.error?, "#{typed.inspect} errored"
    end
  end
end
