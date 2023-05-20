class AddUserFts < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      -- Create an external content fts5 table to index it. c/f https://sqlite.org/fts5.html#external_content_tables
      CREATE VIRTUAL TABLE fts_users USING fts5(name, content='users', content_rowid='id', tokenize='porter unicode61');

      -- Triggers to keep the FTS index up to date.
      CREATE TRIGGER insert_users_search AFTER INSERT ON users BEGIN
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;

      CREATE TRIGGER delete_users_search AFTER DELETE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
      END;

      CREATE TRIGGER update_users_search AFTER UPDATE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
    SQL
  end

  def down
    drop_table :fts_users
  end
end
