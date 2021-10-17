class CreateGrupas < ActiveRecord::Migration[6.1]
  def change
    create_table :grupas do |t|
      t.string :ainm

      t.timestamps
    end
  end
end
