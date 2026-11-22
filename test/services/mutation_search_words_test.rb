require "test_helper"

# The issue's measure of success: each root-form word finds the mutated lines
# it used to miss. The owner chooses the words (#171); WORDS holds the issue's
# own examples until then. Each pair is the word searched and a line that
# should now be found.
class MutationSearchWordsTest < ActiveSupport::TestCase
  WORDS = {
    "bean" => ["Mo bhean!", "ár mbean"],
    "fear" => ["An bhfear seo."],
    "uisce" => ["ár nUisce"]
  }.freeze

  setup do
    speaker = users(:one)
    @lines = WORDS.values.flatten.index_with do |irish|
      DictionaryEntry.create!(speaker: speaker, owner: speaker, word_or_phrase: irish)
    end
    ActiveRecord::Base.connection.execute("INSERT INTO fts_dictionary_entries(fts_dictionary_entries) VALUES('rebuild')")
  end

  WORDS.each do |word, lines|
    test "#{word} finds its mutated lines with forms, and missed them before" do
      lines.each do |line|
        assert_includes DictionaryEntry.search(word, forms: true), @lines[line], "#{word} should find #{line}"
        assert_not_includes DictionaryEntry.search(word), @lines[line]
      end
    end
  end
end
