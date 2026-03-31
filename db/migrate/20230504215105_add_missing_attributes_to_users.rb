class AddMissingAttributesToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :lat_lang, :string
    add_column :users, :role, :integer, null: false, default: 0
    add_column :users, :voice, :integer, null: false, default: 0
    add_column :users, :dialect, :integer, null: false, default: 0
  end
end
