class DropRangIdFromDictionaryEntries < ActiveRecord::Migration[6.1]
  def change
    remove_column :dictionary_entries, :rang_id
  end
end
