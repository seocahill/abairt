class AddStandardIrishToDictionaryEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :dictionary_entries, :standard_irish, :string
  end
end
