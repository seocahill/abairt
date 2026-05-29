class DropUnusedColumnsFromDictionaryEntries < ActiveRecord::Migration[7.0]
  def change
    remove_column :dictionary_entries, :notes
    remove_column :dictionary_entries, :recall_date
    remove_column :dictionary_entries, :previous_inteval
    remove_column :dictionary_entries, :previous_easiness_factor
    remove_column :dictionary_entries, :committed_to_memory
    remove_column :dictionary_entries, :status
    remove_column :dictionary_entries, :tag_list
  end
end
