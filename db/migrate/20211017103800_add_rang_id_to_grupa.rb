class AddRangIdToGrupa < ActiveRecord::Migration[6.1]
  def change
    add_column :rangs, :grupa_id, :string
    add_index :rangs, :grupa_id
  end
end
