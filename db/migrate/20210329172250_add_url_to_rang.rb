class AddUrlToRang < ActiveRecord::Migration[6.1]
  def change
    add_column :rangs, :url, :string
  end
end
