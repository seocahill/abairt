class AddNotesToDictionaryEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :dictionary_entries, :notes, :text
  end
end
