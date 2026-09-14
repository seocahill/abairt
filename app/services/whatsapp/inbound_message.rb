# frozen_string_literal: true

module Whatsapp
  # A single inbound WhatsApp message, pulled out of the webhook envelope.
  #
  #   Whatsapp::InboundMessage.from_payload(params).each { |message| ... }
  #
  # Meta nests messages several layers deep and mixes them in with delivery
  # receipts, so this flattens the envelope and drops everything that is not
  # somebody actually saying something.
  class InboundMessage
    ENVELOPE_PATH = %w[entry changes value messages].freeze

    attr_reader :id, :from, :type, :payload

    def self.from_payload(payload)
      Array(payload["entry"]).flat_map do |entry|
        Array(entry["changes"]).flat_map do |change|
          Array(change.dig("value", "messages")).map { |message| new(message) }
        end
      end
    end

    def initialize(message)
      @id = message["id"]
      @from = message["from"]
      @type = message["type"]
      @payload = message
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
  end
end
