# frozen_string_literal: true

class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.references :asker, null: false, foreign_key: {to_table: :users}
      t.references :speaker, null: false, foreign_key: {to_table: :users}
      t.integer :status, null: false, default: 0
      t.datetime :sent_at
      t.datetime :answered_at
      t.string :wa_question_message_id
      t.string :wa_answer_message_id

      t.timestamps
    end

    # Drives the queue: "does this speaker already have one out with them?"
    add_index :questions, [:speaker_id, :status]
    # Meta redelivers webhooks; this is what makes answering idempotent.
    add_index :questions, :wa_answer_message_id, unique: true
  end
end
