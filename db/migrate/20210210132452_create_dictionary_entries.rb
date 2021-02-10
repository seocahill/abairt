class CreateDictionaryEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :dictionary_entries do |t|
      t.string :word_or_phrase
      t.string :translation

      t.timestamps
    end
  end
end
