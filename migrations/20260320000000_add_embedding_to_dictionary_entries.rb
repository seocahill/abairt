# frozen_string_literal: true

# Creates a sqlite-vec virtual table for storing 1536-dimensional embeddings
# (OpenAI text-embedding-3-small) alongside dictionary entries.
#
# The vec0 virtual table is separate from dictionary_entries — rows are linked
# by dictionary_entry_id. Use EmbedDictionaryEntryJob to populate it.
class AddEmbeddingToDictionaryEntries < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE VIRTUAL TABLE vec_dictionary_entry_embeddings
      USING vec0(
        dictionary_entry_id INTEGER NOT NULL,
        embedding float[1536]
      )
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS vec_dictionary_entry_embeddings"
  end
end
