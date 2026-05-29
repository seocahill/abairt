class CreateMediaImports < ActiveRecord::Migration[7.1]
  def change
    create_table :media_imports do |t|
      t.string :url, null: false
      t.string :title, null: false
      t.text :headline
      t.text :description
      t.integer :status, default: 0, null: false
      t.text :error_message
      t.datetime :imported_at

      t.timestamps
    end

    add_index :media_imports, :status
    add_index :media_imports, :url, unique: true
  end
end
