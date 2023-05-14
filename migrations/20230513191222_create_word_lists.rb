class CreateWordLists < ActiveRecord::Migration[6.1]
  def change
    create_table :word_lists do |t|
      t.string :name
      t.string :description
      t.boolean :starred
      t.belongs_to :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
