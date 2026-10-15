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

      User.answering.telegram.find_by(telegram_chat_id: chat_id)
    end

    # A stranger is how a speaker arrives: they tap Start before we know their
    # chat id. Sharing their number identifies them against the record we
    # already hold, and Telegram vouches for the number, so it is better
    # evidence than anything they could type.
    def onboard
      contact? ? claim : ask_for_number
    end

    # Telegram has no 24 hour window, so there is nothing to record. The method
    # exists because the WhatsApp side of the shared ProcessInbound needs it.
    def note_inbound(speaker)
    end

    private

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
      speaker = User.telegram.where(answers_questions: true)
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
