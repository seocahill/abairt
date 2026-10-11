# frozen_string_literal: true

class AddPasswordAndRememberTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_digest, :string
    add_column :users, :remember_token, :string

    add_index :users, :remember_token, unique: true
  end
end
