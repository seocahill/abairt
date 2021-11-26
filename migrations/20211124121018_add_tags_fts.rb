class AddTagsFts < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      -- Create an external content fts5 table to index it. c/f https://sqlite.org/fts5.html#external_content_tables
      CREATE VIRTUAL TABLE fts_tags USING fts5(name, content='tags', content_rowid='id', tokenize='porter unicode61');

      -- Triggers to keep the FTS index up to date.
      CREATE TRIGGER insert_tags_search AFTER INSERT ON tags BEGIN
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;

      CREATE TRIGGER delete_tags_search AFTER DELETE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
      END;

      CREATE TRIGGER update_tags_search AFTER UPDATE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;
    SQL
  end

  def down
    drop_table :fts_tags
  end
end
