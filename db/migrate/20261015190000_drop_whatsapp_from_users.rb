# frozen_string_literal: true

# WhatsApp is gone, so the columns that only ever served it go too.
#
# `channel` goes with them: with one transport there is nothing to choose
# between, and a column that can only hold one value is a question nobody is
# asking.
#
# The triggers are the catch. `remove_column` on SQLite rebuilds the table, and
# a rebuild silently drops the three triggers that keep user name search
# current — so they are recreated here, verbatim from the migration that
# introduced them (20260331213148_recreate_fts_with_virtual_tables).
class DropWhatsappFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_column :users, :channel
    remove_column :users, :whatsapp_opted_in_at
    remove_column :users, :whatsapp_last_inbound_at
    remove_column :users, :whatsapp_nudged_at

    recreate_user_search_triggers
  end

  def down
    add_column :users, :channel, :integer, default: 0, null: false
    add_column :users, :whatsapp_opted_in_at, :datetime
    add_column :users, :whatsapp_last_inbound_at, :datetime
    add_column :users, :whatsapp_nudged_at, :datetime

    recreate_user_search_triggers
  end

  private

  def recreate_user_search_triggers
    execute "DROP TRIGGER IF EXISTS insert_users_search"
    execute "DROP TRIGGER IF EXISTS delete_users_search"
    execute "DROP TRIGGER IF EXISTS update_users_search"

    execute <<~SQL
      CREATE TRIGGER insert_users_search AFTER INSERT ON users BEGIN
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER delete_users_search AFTER DELETE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
      END;
    SQL

    execute <<~SQL
      CREATE TRIGGER update_users_search AFTER UPDATE ON users BEGIN
        INSERT INTO fts_users(fts_users, rowid, name) VALUES('delete', old.id, old.name);
        INSERT INTO fts_users(rowid, name) VALUES (new.id, new.name);
      END;
    SQL
  end
end
