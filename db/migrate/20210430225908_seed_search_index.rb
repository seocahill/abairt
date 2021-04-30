class SeedSearchIndex < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO search (translation)
      SELECT translation
      FROM dictionary_entries;
    SQL
  end

  def down
    execute <<-SQL
      delete from search
    SQL
  end
end
