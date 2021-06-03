class SeedSearchIndex < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase
      FROM dictionary_entries;
    SQL
  end

  def down
    execute <<-SQL
      delete from fts_dictionary_entries
    SQL
  end
end
