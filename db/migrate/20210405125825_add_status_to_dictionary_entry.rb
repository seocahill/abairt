class AddStatusToDictionaryEntry < ActiveRecord::Migration[6.1]
  def change
    add_column :dictionary_entries, :status, :integer, null: false, default: 0
  end
end
