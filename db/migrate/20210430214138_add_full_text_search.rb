class AddFullTextSearch < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      -- Create an external content fts5 table to index it. c/f https://sqlite.org/fts5.html#external_content_tables
      CREATE VIRTUAL TABLE fts_dictionary_entries USING fts5(translation, word_or_phrase, content='dictionary_entries', content_rowid='id', tokenize='porter unicode61');

      -- Triggers to keep the FTS index up to date.
      CREATE TRIGGER insert_search AFTER INSERT ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(rowid, translation) VALUES (new.id, new.translation, new.word_or_phrase);
      END;

      CREATE TRIGGER delete_search AFTER DELETE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation) VALUES('delete', old.id, old.translation, old.word_or_phrase);
      END;

      CREATE TRIGGER update_search AFTER UPDATE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation) VALUES('delete', old.id, old.translation, old.word_or_phrase);
        INSERT INTO fts_dictionary_entries(rowid, translation) VALUES (new.id, new.translation, new.word_or_phrase);
      END;
    SQL
  end

  def down
    drop_table :fts_dictionary_entries
  end
end
