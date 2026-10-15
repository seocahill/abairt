# frozen_string_literal: true

class ProcessTelegramMessageJob < ApplicationJob
  queue_as :default

  def perform(payload)
    Telegram::InboundMessage.from_payload(payload).each do |message|
      ProcessInbound.new(message).call
    end
  end
end
