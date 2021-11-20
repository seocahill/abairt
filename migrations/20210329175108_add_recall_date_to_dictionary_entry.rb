class AddRecallDateToDictionaryEntry < ActiveRecord::Migration[6.1]
  def change
    add_column :dictionary_entries, :recall_date, :datetime
  end
end
