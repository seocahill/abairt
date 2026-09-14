# frozen_string_literal: true

class ProcessWhatsappMessageJob < ApplicationJob
  queue_as :default

  def perform(payload)
    Whatsapp::InboundMessage.from_payload(payload).each do |message|
      Whatsapp::ProcessInbound.new(message).call
    end
  end
end
