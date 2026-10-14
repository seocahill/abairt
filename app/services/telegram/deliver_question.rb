# frozen_string_literal: true

module Telegram
  # Sends one question to the speaker as a voice note.
  #
  #   Telegram::DeliverQuestion.new(question).call # => message id, or nil
  #
  # Returns nil when it did not get through, in which case the question stays
  # `waiting` and goes out on the next attempt.
  #
  # Shorter than its WhatsApp counterpart for one reason: there is no 24 hour
  # window, so there is no template, no nudge and nothing to approve. If we hold
  # a chat id the voice note can go out, whenever it was last used.
  class DeliverQuestion
    def initialize(question, client: Client.new)
      @question = question
      @speaker = question.speaker
      @client = client
    end

    def call
      message_id = OpusVoiceNote.new(@question.audio).open do |path|
        @client.send_voice(chat_id: @speaker.telegram_chat_id, path: path)
      end

      "telegram:#{@speaker.telegram_chat_id}:#{message_id}"
    rescue Client::Error, OpusVoiceNote::TranscodeError => e
      # Leave the question waiting rather than wedging the queue on one bad file.
      Rails.logger.error("DeliverQuestion failed for Question##{@question.id}: #{e.message}")
      nil
    end
  end
end
