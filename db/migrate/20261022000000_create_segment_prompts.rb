# frozen_string_literal: true

# One segment sent to one speaker to be checked.
#
# Its own table rather than columns on dictionary_entries, which is the largest
# table here and has nothing to do with Telegram. It also gives the state the
# entry cannot hold: a correction arrives as a voice note, which is not an edit
# anybody can apply automatically, so the segment is neither still unchecked nor
# confirmed — it is corrected, and waiting for somebody to write the correction
# down. That queue is `SegmentPrompt.corrected`.
class CreateSegmentPrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :segment_prompts do |t|
      t.references :dictionary_entry, null: false, foreign_key: true
      t.references :speaker, null: false, foreign_key: {to_table: :users}
      t.integer :status, null: false, default: 0
      t.datetime :sent_at
      t.datetime :answered_at
      # Namespaced with the chat that issued it: a Telegram message id is only
      # unique within its chat.
      t.string :message_id

      t.timestamps
    end

    add_index :segment_prompts, [:speaker_id, :status]
    add_index :segment_prompts, :message_id, unique: true
  end
end
