class AddRegionAttributesToDictionaryEntries < ActiveRecord::Migration[6.1]
  def change
    add_column :dictionary_entries, :region_start, :decimal
    add_column :dictionary_entries, :region_end, :decimal
    add_column :dictionary_entries, :region_id, :string
  end
end
