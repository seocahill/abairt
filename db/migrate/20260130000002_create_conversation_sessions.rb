# frozen_string_literal: true

class CreateConversationSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :voice_recording, foreign_key: true
      t.references :current_entry, foreign_key: { to_table: :dictionary_entries }

      t.string :state, default: "idle", null: false
      t.jsonb :conversation_history, default: []
      t.jsonb :context, default: {}

      t.timestamps
    end

    add_index :conversation_sessions, :state
  end
end
