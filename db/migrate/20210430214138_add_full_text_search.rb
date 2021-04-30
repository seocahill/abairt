class AddFullTextSearch < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      -- Create an external content fts5 table to index it.
      CREATE VIRTUAL TABLE fts_idx USING fts5(translation, content='dictionary_entries', content_rowid='id');

      -- Bulk insert existing data
      INSERT INTO fts_idx (translation)
      SELECT translation
      FROM dictinary_entries;

      -- Triggers to keep the FTS index up to date.
      CREATE TRIGGER tbl_dei AFTER INSERT ON dictionary_entries BEGIN
        INSERT INTO fts_idx(rowid, translation) VALUES (new.id, new.translation);
      END;

      CREATE TRIGGER tbl_ded AFTER DELETE ON dictionary_entries BEGIN
        INSERT INTO fts_idx(fts_idx, rowid, translation) VALUES('delete', old.id, old.translation);
      END;

      CREATE TRIGGER tbl_deu AFTER UPDATE ON dictionary_entries BEGIN
        INSERT INTO fts_idx(fts_idx, rowid, translation) VALUES('delete', old.id, old.translation);
        INSERT INTO fts_idx(rowid, translation) VALUES (new.id, new.translation);
      END;
    SQL
  end

  def down
    drop_table :fts_idx
  end
end
