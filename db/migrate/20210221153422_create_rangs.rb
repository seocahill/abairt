# frozen_string_literal: true

class CreateRangs < ActiveRecord::Migration[6.1]
  def change
    create_table :rangs do |t|
      t.string :name
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
