# frozen_string_literal: true

# Abairt used to be a learning platform too. The tables and columns below are
# what is left of that: no model, no reference in the code, nothing reads or
# writes them (#121, step 4). Learning lives in the Mayo Irish course now.
#
# - learning_sessions, learning_progresses: spaced-repetition progress
# - courses, and items (each item belongs to a course, so it has to go too)
# - articles
# - grupas and seomras: the old class groups and class memberships
# - users.token, users.master_id, users.grupa_id: sign-in tokens live in
#   login_token, remember_token, api_token and telegram_invite_token now
#
# `conversations`, `settings`, `rangs` and `rang_entries` are left alone
# (`rangs.grupa_id` is an old plain column with no foreign key, so it simply
# points nowhere now).
#
# The triggers are the catch. `remove_column` on SQLite rebuilds `users`, and
# a rebuild silently drops the three triggers that keep user name search
# current, so they are recreated here, verbatim from
# 20260331213148_recreate_fts_with_virtual_tables (as DropWhatsappFromUsers
# does).
#
# The rebuild also resets the AUTOINCREMENT counter for `users` to the highest
# id still present, so if the newest accounts were deleted their ids would be
# handed out again, and anything still pointing at them by id (versions,
# taggings) would attach to the new person. `keeping_user_ids_unique` puts the
# counter back.
#
# `down` restores the structure, empty. The rows are not coming back, so take
# a backup before running this.
class DropLearnerEraSchema < ActiveRecord::Migration[8.1]
  def up
    drop_table :learning_progresses
    drop_table :learning_sessions
    drop_table :items
    drop_table :courses
    drop_table :articles
    drop_table :seomras
    drop_table :grupas

    remove_index :users, :token
    remove_index :users, :master_id
    remove_index :users, :grupa_id
    keeping_user_ids_unique do
      remove_columns :users, :token, :master_id, :grupa_id
    end

    recreate_user_search_triggers
  end

  def down
    add_column :users, :token, :string, limit: 255
    add_column :users, :master_id, :bigint
    add_column :users, :grupa_id, :bigint
    add_index :users, :token
    add_index :users, :master_id
    add_index :users, :grupa_id
    recreate_user_search_triggers

    create_learner_tables
  end

  private

  # Rails rebuilds through a temporary copy, which creates a temporary
  # sqlite_sequence that shadows the real one, hence `main.`.
  def keeping_user_ids_unique
    last_id = select_value("SELECT seq FROM main.sqlite_sequence WHERE name = 'users'").to_i
    yield
    last_id = [last_id, select_value("SELECT MAX(id) FROM users").to_i].max
    execute "DELETE FROM main.sqlite_sequence WHERE name = 'users'"
    execute "INSERT INTO main.sqlite_sequence (name, seq) VALUES ('users', #{last_id})"
  end

  def create_learner_tables
    create_table :grupas do |t|
      t.string :ainm
      t.timestamps
      t.bigint :muinteoir_id, index: true
      t.string :lat_lang
    end

    create_table :seomras do |t|
      t.references :user, null: false, foreign_key: true
      t.references :rang, null: false, foreign_key: true
      t.timestamps
    end

    create_table :articles do |t|
      t.string :title
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :courses do |t|
      t.string :name
      t.text :description
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    create_table :items do |t|
      t.string :name
      t.text :description
      t.references :course, null: false, foreign_key: true
      t.references :itemable, polymorphic: true, null: false
      t.timestamps
    end

    create_table :learning_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :learnable, polymorphic: true, null: false
      t.timestamps
    end

    create_table :learning_progresses do |t|
      t.integer :repetition_number, default: 0, null: false
      t.float :ease_factor, default: 0.0, null: false
      t.date :next_review_date
      t.date :last_review_date
      t.integer :quality_of_last_review
      t.references :learning_session, null: false, foreign_key: true
      t.references :dictionary_entry, null: false, foreign_key: true
      t.timestamps
      t.boolean :completed, default: false, null: false
      t.integer :interval, default: 0, null: false
    end
  end

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
