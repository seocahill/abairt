class AddTokenToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :token, :string
    add_index :users, :token
  end
end
