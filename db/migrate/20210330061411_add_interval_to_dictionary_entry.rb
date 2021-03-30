class AddIntervalToDictionaryEntry < ActiveRecord::Migration[6.1]
  def change
    add_column :dictionary_entries, :previous_inteval, :integer, null: false, default: 0
    add_column :dictionary_entries, :previous_easiness_factor, :decimal, null: false, default: 2.5
  end
end
