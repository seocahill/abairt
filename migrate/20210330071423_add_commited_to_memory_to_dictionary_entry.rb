class AddCommitedToMemoryToDictionaryEntry < ActiveRecord::Migration[6.1]
  def change
    add_column :dictionary_entries, :committed_to_memory, :boolean, null: false, default: false
  end
end
