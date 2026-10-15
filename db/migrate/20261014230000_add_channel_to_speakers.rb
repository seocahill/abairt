# frozen_string_literal: true

# A speaker's transport becomes a property of the speaker rather than an
# assumption baked into the code.
#
# The two `questions` columns are renamed because they are about to hold
# Telegram message ids as well: a message id is a message id whatever sent it.
#
# `users` is only added to, never altered. `rename_column` on SQLite rebuilds
# the table, which silently drops the three FTS triggers that keep user name
# search current — so `whatsapp_last_inbound_at` and `whatsapp_opted_in_at`
# keep their names despite now being channel-agnostic. The 24 hour window they
# serve is a WhatsApp concept anyway, and the WhatsApp adapter owns them.
class AddChannelToSpeakers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :channel, :integer, default: 0, null: false
    add_column :users, :telegram_chat_id, :string
    add_index :users, :telegram_chat_id, unique: true

    rename_column :questions, :wa_question_message_id, :question_message_id
    rename_column :questions, :wa_answer_message_id, :answer_message_id
  end
end
