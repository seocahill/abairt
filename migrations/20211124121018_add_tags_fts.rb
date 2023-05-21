class AddTagsFts < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      -- Create an external content fts5 table to index it. c/f https://sqlite.org/fts5.html#external_content_tables
      CREATE VIRTUAL TABLE fts_tags USING fts5(name, content='tags', content_rowid='id', tokenize='porter unicode61');
    SQL
  end

  def down
    drop_table :fts_tags
  end
end
