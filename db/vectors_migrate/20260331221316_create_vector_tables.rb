class CreateVectorTables < ActiveRecord::Migration[8.1]
  def up
    # Create virtual table for dictionary entry embeddings using sqlite-vec
    execute <<-SQL
      CREATE VIRTUAL TABLE vec_dictionary_entry_embeddings
      USING vec0(
        dictionary_entry_id INTEGER NOT NULL,
        embedding float[1536]
      );
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS vec_dictionary_entry_embeddings;"
  end
end
