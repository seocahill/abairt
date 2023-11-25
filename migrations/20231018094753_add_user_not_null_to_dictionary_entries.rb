class AddUserNotNullToDictionaryEntries < ActiveRecord::Migration[7.0]
  def change
    change_column_null :dictionary_entries, :user_id, false
  end
end
