class CreateRangEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :rang_entries do |t|
      t.references :rang, null: false, foreign_key: true
      t.references :dictionary_entry, null: false, foreign_key: true

      t.timestamps
    end
  end
end
