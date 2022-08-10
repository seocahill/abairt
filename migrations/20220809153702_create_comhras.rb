class CreateComhras < ActiveRecord::Migration[6.1]
  def change
    create_table :comhras do |t|
      t.string :name
      t.string :lat_lang
      t.references :user, null: false, foreign_key: true
      t.references :grupa, null: false, foreign_key: true

      t.timestamps
    end
  end
end
