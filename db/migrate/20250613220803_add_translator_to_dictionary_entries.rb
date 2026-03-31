class AddTranslatorToDictionaryEntries < ActiveRecord::Migration[7.1]
  def change
    add_reference :dictionary_entries, :translator, null: true, foreign_key: { to_table: :users }
  end
end
