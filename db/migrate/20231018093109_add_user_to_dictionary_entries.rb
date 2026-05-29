class AddUserToDictionaryEntries < ActiveRecord::Migration[7.0]
  def change
    add_reference :dictionary_entries, :user, foreign_key: true
  end
end
