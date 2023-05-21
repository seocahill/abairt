class SeedUsersSearchIndex < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_users(rowid, name)
      SELECT id, name
      FROM users;
    SQL
  end

  def down
    execute <<-SQL
      delete from fts_users
    SQL
  end
end
