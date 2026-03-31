class AddStatusToDictionaryEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :dictionary_entries, :status, :integer, default: 0, null: false
  end
end
