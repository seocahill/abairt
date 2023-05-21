class EnableTriggers < ActiveRecord::Migration[6.1]
  def up
    # drop first could be some bad triggers hiding in there
    execute <<-SQL
      DROP TRIGGER IF EXISTS insert_search;
      DROP TRIGGER IF EXISTS delete_search;
      DROP TRIGGER IF EXISTS update_search;
      DROP TRIGGER IF EXISTS insert_tags_search;
      DROP TRIGGER IF EXISTS delete_tags_search;
      DROP TRIGGER IF EXISTS update_tags_search;
      DROP TRIGGER IF EXISTS insert_users_search;
      DROP TRIGGER IF EXISTS delete_users_search;
      DROP TRIGGER IF EXISTS update_users_search;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS insert_search AFTER INSERT ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase) VALUES (new.id, new.translation, new.word_or_phrase);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS delete_search AFTER DELETE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation, word_or_phrase) VALUES('delete', old.id, old.translation, old.word_or_phrase);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS update_search AFTER UPDATE ON dictionary_entries BEGIN
        INSERT INTO fts_dictionary_entries(fts_dictionary_entries, rowid, translation, word_or_phrase) VALUES('delete', old.id, old.translation, old.word_or_phrase);
        INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase) VALUES (new.id, new.translation, new.word_or_phrase);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS insert_tags_search AFTER INSERT ON tags BEGIN
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS delete_tags_search AFTER DELETE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS update_tags_search AFTER UPDATE ON tags BEGIN
        INSERT INTO fts_tags(fts_tags, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_tags(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS insert_users_search AFTER INSERT ON users BEGIN
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS delete_users_search AFTER DELETE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER IF NOT EXISTS update_users_search AFTER UPDATE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS insert_search;
      DROP TRIGGER IF EXISTS delete_search;
      DROP TRIGGER IF EXISTS update_search;
      DROP TRIGGER IF EXISTS insert_tags_search;
      DROP TRIGGER IF EXISTS delete_tags_search;
      DROP TRIGGER IF EXISTS update_tags_search;
      DROP TRIGGER IF EXISTS insert_users_search;
      DROP TRIGGER IF EXISTS delete_users_search;
      DROP TRIGGER IF EXISTS update_users_search;
    SQL
  end
end
