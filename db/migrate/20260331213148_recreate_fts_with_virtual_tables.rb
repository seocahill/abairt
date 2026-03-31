class RecreateFtsWithVirtualTables < ActiveRecord::Migration[8.1]
  def up
    # Drop old triggers
    execute "DROP TRIGGER IF EXISTS insert_search"
    execute "DROP TRIGGER IF EXISTS delete_search"
    execute "DROP TRIGGER IF EXISTS update_search"
    execute "DROP TRIGGER IF EXISTS insert_tags_search"
    execute "DROP TRIGGER IF EXISTS delete_tags_search"
    execute "DROP TRIGGER IF EXISTS update_tags_search"
    execute "DROP TRIGGER IF EXISTS insert_users_search"
    execute "DROP TRIGGER IF EXISTS delete_users_search"
    execute "DROP TRIGGER IF EXISTS update_users_search"

    # Drop old FTS tables
    drop_table :fts_dictionary_entries, if_exists: true
    drop_table :fts_tags, if_exists: true
    drop_table :fts_users, if_exists: true

    # Create FTS5 virtual tables using Rails 8 syntax
    create_virtual_table :fts_dictionary_entries, :fts5, [
      "translation",
      "word_or_phrase",
      "content='dictionary_entries'",
      "content_rowid='id'",
      "tokenize='porter unicode61'"
    ]

    create_virtual_table :fts_tags, :fts5, [
      "name",
      "content='tags'",
      "content_rowid='id'",
      "tokenize='porter unicode61'"
    ]

    create_virtual_table :fts_users, :fts5, [
      "name",
      "content='users'",
      "content_rowid='id'",
      "tokenize='porter unicode61'"
    ]

    # Create triggers for dictionary_entries
    execute <<-SQL
      CREATE TRIGGER insert_search AFTER INSERT ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
        VALUES (new.id, new.translation, new.word_or_phrase);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER delete_search AFTER DELETE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation, word_or_phrase)
        VALUES('delete', old.id, old.translation, old.word_or_phrase);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER update_search AFTER UPDATE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation, word_or_phrase)
        VALUES('delete', old.id, old.translation, old.word_or_phrase);
        INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
        VALUES (new.id, new.translation, new.word_or_phrase);
      END;
    SQL

    # Create triggers for tags
    execute <<-SQL
      CREATE TRIGGER insert_tags_search AFTER INSERT ON tags BEGIN
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER delete_tags_search AFTER DELETE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER update_tags_search AFTER UPDATE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    # Create triggers for users
    execute <<-SQL
      CREATE TRIGGER insert_users_search AFTER INSERT ON users BEGIN
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER delete_users_search AFTER DELETE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER update_users_search AFTER UPDATE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    # Reseed FTS tables with existing data
    execute <<-SQL
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase FROM dictionary_entries;
    SQL

    execute <<-SQL
      INSERT INTO fts_tags(rowid, name)
      SELECT id, name FROM tags;
    SQL

    execute <<-SQL
      INSERT INTO fts_users(rowid, name)
      SELECT id, name FROM users;
    SQL
  end

  def down
    # Drop triggers
    execute "DROP TRIGGER IF EXISTS insert_search"
    execute "DROP TRIGGER IF EXISTS delete_search"
    execute "DROP TRIGGER IF EXISTS update_search"
    execute "DROP TRIGGER IF EXISTS insert_tags_search"
    execute "DROP TRIGGER IF EXISTS delete_tags_search"
    execute "DROP TRIGGER IF EXISTS update_tags_search"
    execute "DROP TRIGGER IF EXISTS insert_users_search"
    execute "DROP TRIGGER IF EXISTS delete_users_search"
    execute "DROP TRIGGER IF EXISTS update_users_search"

    # Drop FTS tables
    drop_table :fts_dictionary_entries
    drop_table :fts_tags
    drop_table :fts_users
  end
end
