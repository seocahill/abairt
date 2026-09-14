# frozen_string_literal: true

module Whatsapp
  # Decides what a message arriving from a speaker means.
  #
  #   Whatsapp::ProcessInbound.new(message).call
  #
  # There are only two possibilities, and the speaker never has to signal which
  # one they mean:
  #
  #   * a voice note while holding a question  -> that is the answer
  #   * anything else (a button tap, a hello)  -> reopens the 24 hour window,
  #                                               so send them what is waiting
  class ProcessInbound
    def initialize(message)
      @message = message
    end

    def call
      speaker = find_speaker
      return if speaker.nil?

      # Any inbound message reopens the window — record it before anything else
      # decides whether it can send.
      speaker.update!(whatsapp_last_inbound_at: Time.current)

      record_answer(speaker) if @message.audio?
      QuestionQueue.new(speaker).deliver_next
    end

    private

    def find_speaker
      speaker = User.answering.find_by(phone_number: @message.from)
      Rails.logger.info("Ignoring WhatsApp message from unknown number") if speaker.nil?
      speaker
    end

    def record_answer(speaker)
      question = QuestionQueue.new(speaker).outstanding
      return if question.nil?

      RecordAnswer.new(question, @message).call
    end
  end
end
