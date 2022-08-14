class AddLatLangToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :lat_lang, :string
  end
end
