# frozen_string_literal: true

module Telegram
  # Long polls for updates and feeds them through the ordinary inbound path.
  #
  #   Telegram::Poller.new.run          # until interrupted
  #   Telegram::Poller.new.run(once: true)
  #
  # For local development and for the first run with a real speaker, where
  # there is no public URL to point a webhook at. Nothing here is a parallel
  # implementation: an update polled is handed to the same InboundMessage and
  # ProcessInbound the webhook uses, so what works under this works deployed.
  #
  # Not for production, where the webhook earns its keep — this holds a
  # connection open and runs outside the request cycle.
  class Poller
    class WebhookInTheWay < StandardError; end

    def initialize(client: Client.new, logger: Rails.logger)
      @client = client
      @logger = logger
      @offset = nil
    end

    def run(once: false)
      loop do
        poll
        break if once
      end
    end

    def poll
      updates = fetch
      updates.each { |update| handle(update) }
      updates.size
    end

    private

    def fetch
      @client.get_updates(offset: @offset)
    rescue Client::Error => e
      # Telegram says 409 when a webhook is set. Deleting it here could take
      # production offline, so this stops and says so instead.
      raise unless e.message.include?("409")

      raise WebhookInTheWay, "A webhook is set for this bot, so polling is refused. " \
        "Use a separate bot for development, or call deleteWebhook if that webhook is not in use."
    end

    def handle(update)
      # Acknowledged whatever happens below: a message we cannot process is
      # still one we should not be handed again for ever.
      @offset = update["update_id"] + 1

      InboundMessage.from_payload(update).each do |message|
        @logger.info("Telegram update #{update["update_id"]} from chat #{message.chat_id}")
        ProcessInbound.new(message).call
      end
    rescue => e
      @logger.error("Telegram update #{update["update_id"]} failed: #{e.class}: #{e.message}")
    end
  end
end
