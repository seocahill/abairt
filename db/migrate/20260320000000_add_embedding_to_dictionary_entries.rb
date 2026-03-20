# frozen_string_literal: true

class AddEmbeddingToDictionaryEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :dictionary_entries, :embedding, :binary
  end
end
