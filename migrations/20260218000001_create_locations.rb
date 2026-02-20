# frozen_string_literal: true

class CreateLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :irish_name
      t.integer :location_type, default: 0, null: false  # townland, parish, barony, county
      t.integer :dialect_region, default: 0, null: false # erris, achill, tourmakeady, other
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.references :parent
      t.timestamps
    end

    add_index :locations, :name
    add_index :locations, :dialect_region
  end
end
