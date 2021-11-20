# frozen_string_literal: true

class AddConfirmedToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :confirmed, :boolean, null: false, default: false
  end
end
