# frozen_string_literal: true

class AddWhatsappToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :phone_number, :string
    add_column :users, :answers_questions, :boolean, null: false, default: false
    add_column :users, :whatsapp_opted_in_at, :datetime
    add_column :users, :whatsapp_last_inbound_at, :datetime
    add_column :users, :whatsapp_nudged_at, :datetime

    add_index :users, :phone_number, unique: true
  end
end
