class AddComhraIdToDictionaryEntries < ActiveRecord::Migration[6.1]
  def change
    add_reference :dictionary_entries, :comhra, foreign_key: false
  end
end
