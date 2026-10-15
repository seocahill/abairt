# frozen_string_literal: true

# An invite link is how a speaker is connected to their chat without us holding
# a phone number for them. They tap `t.me/<bot>?start=<token>` once; Telegram
# hands the token to the bot, and the chat is claimed by whoever the token
# belongs to.
#
# Single use: the token is cleared the moment it is redeemed, so a forwarded
# link claims nothing.
class AddTelegramInviteTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :telegram_invite_token, :string
    add_index :users, :telegram_invite_token, unique: true
  end
end
