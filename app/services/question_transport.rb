# frozen_string_literal: true

# Picks the adapter that will carry a question to its speaker.
#
#   QuestionTransport.for(question).call # => message id, or nil
#
# This is the only place in the app that knows more than one transport exists.
# QuestionQueue, QuestionRouter, the draft/send flow and the admin backlog never
# knew what the transport was, which is what makes the choice swappable — and
# lets one speaker be on Telegram while another is on WhatsApp.
module QuestionTransport
  ADAPTERS = {
    "whatsapp" => Whatsapp::DeliverQuestion,
    "telegram" => Telegram::DeliverQuestion
  }.freeze

  def self.for(question)
    ADAPTERS.fetch(question.speaker.channel).new(question)
  end
end
