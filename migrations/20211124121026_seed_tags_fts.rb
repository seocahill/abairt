class SeedTagsFts < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_tags(rowid, name)
      SELECT id, name
      FROM tags;
    SQL
  end

  def down
    execute <<-SQL
      delete from fts_tags
    SQL
  end
end
