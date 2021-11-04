class AddMuinteoirIdToGrupas < ActiveRecord::Migration[6.1]
  def change
    add_column :grupas, :muinteoir_id, :bigint
    add_index :grupas, :muinteoir_id
  end
end
