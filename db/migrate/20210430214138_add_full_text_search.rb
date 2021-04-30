class AddFullTextSearch < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      -- Create an external content fts5 table to index it. c/f https://sqlite.org/fts5.html#external_content_tables
      CREATE VIRTUAL TABLE search USING fts5(translation, word_or_phrase UNINDEXED, content='dictionary_entries', content_rowid='id');

      -- Triggers to keep the FTS index up to date.
      CREATE TRIGGER insert_search AFTER INSERT ON dictionary_entries BEGIN
        INSERT INTO search(rowid, translation) VALUES (new.id, new.translation);
      END;

      CREATE TRIGGER delete_search AFTER DELETE ON dictionary_entries BEGIN
        INSERT INTO search(search, rowid, translation) VALUES('delete', old.id, old.translation);
      END;

      CREATE TRIGGER update_search AFTER UPDATE ON dictionary_entries BEGIN
        INSERT INTO search(search, rowid, translation) VALUES('delete', old.id, old.translation);
        INSERT INTO search(rowid, translation) VALUES (new.id, new.translation);
      END;
    SQL
  end

  def down
    drop_table :search
  end
end
