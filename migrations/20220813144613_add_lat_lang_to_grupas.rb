class AddLatLangToGrupas < ActiveRecord::Migration[6.1]
  def change
    add_column :grupas, :lat_lang, :string
  end
end
