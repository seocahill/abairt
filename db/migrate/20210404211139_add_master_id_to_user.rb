class AddMasterIdToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :master_id, :bigint
    add_index :users, :master_id
  end
end
