class CreateWordListDictionaryEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :word_list_dictionary_entries do |t|
      t.belongs_to :dictionary_entry, null: false, foreign_key: true
      t.belongs_to :word_list, null: false, foreign_key: true

      t.timestamps
    end
  end
end
