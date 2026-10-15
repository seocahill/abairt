# frozen_string_literal: true

module Whatsapp
  # A single inbound WhatsApp message, pulled out of the webhook envelope.
  #
  #   Whatsapp::InboundMessage.from_payload(params).each { |message| ... }
  #
  # Meta nests messages several layers deep and mixes them in with delivery
  # receipts, so this flattens the envelope and drops everything that is not
  # somebody actually saying something.
  #
  # Presents the same face as Telegram::InboundMessage, which is what lets one
  # ProcessInbound serve both.
  class InboundMessage
    attr_reader :from, :type, :payload

    def self.from_payload(payload)
      Array(payload["entry"]).flat_map do |entry|
        Array(entry["changes"]).flat_map do |change|
          Array(change.dig("value", "messages")).map { |message| new(message) }
        end
      end
    end

    def initialize(message, client: Client.new)
      @from = message["from"]
      @type = message["type"]
      @payload = message
      @client = client
    end

    # Prefixed for the same reason Telegram's is: both transports' ids land in
    # the same uniquely-indexed column, and saying which one sent it costs
    # nothing. A wamid is already globally unique on its own.
    def id
      "whatsapp:#{@payload["id"]}"
    end

    def audio?
      type == "audio"
    end

    # Tapping a template's quick-reply button is how a speaker reopens the 24
    # hour window without typing anything.
    def button?
      %w[button interactive].include?(type)
    end

    def audio_media_id
      payload.dig("audio", "id")
    end

    def text
      payload.dig("text", "body")
    end

    def download_audio
      @client.download_media(audio_media_id)
    end

    def speaker
      return nil if from.blank?

      User.answering.whatsapp.find_by(phone_number: from)
    end

    # Nothing to be done with a number we do not know. Unlike Telegram, where a
    # stranger is how a speaker arrives, a WhatsApp speaker is set up by hand
    # before they ever message us.
    def onboard
      Rails.logger.info("Ignoring WhatsApp message from unknown number")
      nil
    end

    # Any inbound message reopens the 24 hour window.
    def note_inbound(speaker)
      speaker.update!(whatsapp_last_inbound_at: Time.current)
    end
  end
end
