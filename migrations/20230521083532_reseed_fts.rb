class ReseedFts < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase
      FROM dictionary_entries;
    SQL

    execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_tags(rowid, name)
      SELECT id, name
      FROM tags;
    SQL

    execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_users(rowid, name)
      SELECT id, name
      FROM users;
    SQL
  end

  def down
    execute <<-SQL
      delete from fts_dictionary_entries;
      delete from fts_tags;
      delete from fts_users;
    SQL
  end
end
