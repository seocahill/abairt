# frozen_string_literal: true

module Telegram
  # A single inbound Telegram message, pulled out of the webhook envelope.
  #
  #   Telegram::InboundMessage.from_payload(params).each { |message| ... }
  #
  # One webhook delivery carries one update, so this yields nought or one. Edits
  # and everything else Telegram can send are ignored — a speaker only ever
  # sends a voice note, and the one tap that identifies them.
  class InboundMessage
    GREETING = "Fáilte! Brúigh an cnaipe thíos chun tosú."
    SHARE_BUTTON = "Seol m'uimhir"
    WELCOME = "Tá tú istigh. Gheobhaidh tú ceist anseo go luath."
    # `t.me/<bot>?start=<token>` arrives as this. Telegram allows base64url in
    # the payload, which is what has_secure_token produces.
    INVITE = %r{\A/start\s+([A-Za-z0-9_-]+)\z}

    attr_reader :payload

    def self.from_payload(payload)
      message = payload["message"]
      message.present? ? [new(message)] : []
    end

    def initialize(message, client: Client.new)
      @payload = message
      @client = client
    end

    # Namespaced because a Telegram message id is unique only within its chat.
    # `questions.answer_message_id` carries a unique index and holds ids from
    # both transports, so two speakers' message 42 must not collide.
    def id
      "telegram:#{chat_id}:#{@payload["message_id"]}"
    end

    def chat_id
      @payload.dig("chat", "id").to_s
    end

    def audio?
      @payload.key?("voice")
    end

    def download_audio
      @client.download_file(@payload.dig("voice", "file_id"))
    end

    def speaker
      return nil if chat_id.blank?

      User.answering.find_by(telegram_chat_id: chat_id)
    end

    # A stranger is how a speaker arrives. Two ways to find out who they are:
    #
    #   * they followed an invite link, which carries a token naming them. One
    #     tap, nothing typed, and no phone number needed.
    #   * they shared their phone number, which is matched against a record we
    #     already hold. Telegram vouches for the number, so it is better
    #     evidence than anything they could type.
    #
    # The link is the one to hand out. The number is the fallback for a speaker
    # who arrives without one.
    def onboard
      return redeem_invite if invite_token.present?

      contact? ? claim : ask_for_number
    end

    private

    def invite_token
      @payload["text"].to_s[INVITE, 1]
    end

    # Single use: the token is cleared as it is redeemed, so a link that gets
    # forwarded or screenshotted claims nothing afterwards.
    def redeem_invite
      speaker = User.where(answers_questions: true)
        .find_by(telegram_invite_token: invite_token)

      if speaker.nil?
        Rails.logger.warn("Telegram invite token does not match any speaker")
        return nil
      end

      speaker.update!(telegram_chat_id: chat_id, telegram_invite_token: nil)
      say_hello
      speaker
    end

    def say_hello
      @client.send_text(chat_id: chat_id, text: WELCOME)
    rescue Client::Error => e
      # They are connected either way; the greeting is a courtesy.
      Rails.logger.error("Could not greet Telegram chat #{chat_id}: #{e.message}")
    end

    def contact?
      @payload.key?("contact")
    end

    def claim
      # A contact card can be anyone's — Telegram lets you forward one from your
      # address book — so only a card describing the sender may claim a speaker.
      unless @payload.dig("contact", "user_id").to_s == @payload.dig("from", "id").to_s
        Rails.logger.warn("Ignoring a Telegram contact card for somebody else")
        return nil
      end

      # Deliberately not `answering`, which requires the chat id this is about to
      # set — a speaker expecting a chat does not have one yet.
      speaker = User.where(answers_questions: true)
        .find_by(phone_number: @payload.dig("contact", "phone_number"))
      if speaker.nil?
        Rails.logger.warn("No speaker is expecting a Telegram chat for that number")
        return nil
      end

      # No separate opt-in timestamp: a bot cannot message anyone who has not
      # started it, so holding their chat id *is* the consent record.
      speaker.update!(telegram_chat_id: chat_id)
      speaker
    end

    def ask_for_number
      @client.request_contact(chat_id: chat_id, text: GREETING, button: SHARE_BUTTON)
      nil
    rescue Client::Error => e
      Rails.logger.error("Could not greet Telegram chat #{chat_id}: #{e.message}")
      nil
    end
  end
end
