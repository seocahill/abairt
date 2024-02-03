class CreateItems < ActiveRecord::Migration[7.0]
  def change
    create_table :items do |t|
      t.string :name
      t.text :description
      t.references :course, null: false, foreign_key: true
      t.references :itemable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
