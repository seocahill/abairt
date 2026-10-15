# frozen_string_literal: true

namespace :telegram do
  desc "Long poll for Telegram updates and handle them (local development)"
  task poll: :environment do
    puts "Polling for Telegram updates. Ctrl-C to stop."
    Telegram::Poller.new.run
  rescue Telegram::Poller::WebhookInTheWay => e
    abort e.message
  rescue Interrupt
    puts "\nStopped."
  end
end
