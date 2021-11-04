class AddGrupaIdToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :grupa_id, :bigint
    add_index :users, :grupa_id
  end
end
