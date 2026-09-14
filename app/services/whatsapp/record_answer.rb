# frozen_string_literal: true

module Whatsapp
  # Files a speaker's voice note as the answer to the question they are holding.
  #
  #   Whatsapp::RecordAnswer.new(question, message).call
  #
  # No matching logic is needed because of the one-at-a-time rule: whatever they
  # send back is the answer to their single outstanding question.
  class RecordAnswer
    def initialize(question, message, client: Client.new)
      @question = question
      @message = message
      @client = client
    end

    def call
      return false if already_recorded?

      attach_audio
      @question.update!(
        status: :answered,
        answered_at: Time.current,
        wa_answer_message_id: @message.id
      )
      notify_asker
      true
    rescue Client::Error => e
      Rails.logger.error("RecordAnswer failed for Question##{@question.id}: #{e.message}")
      false
    end

    private

    # Meta redelivers webhooks, so the same voice note can arrive more than once.
    def already_recorded?
      @question.wa_answer_message_id == @message.id ||
        Question.exists?(wa_answer_message_id: @message.id)
    end

    def attach_audio
      @question.answer_audio.attach(
        io: StringIO.new(@client.download_media(@message.audio_media_id)),
        filename: "answer_#{@question.id}.ogg",
        content_type: "audio/ogg"
      )
    end

    def notify_asker
      QuestionMailer.answered(@question).deliver_later
    end
  end
end
