class AddQualityToDictionaryEntry < ActiveRecord::Migration[7.0]
  def change
    add_column :dictionary_entries, :quality, :integer, null: false, default: 0
  end
end
