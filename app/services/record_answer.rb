# frozen_string_literal: true

# Files a speaker's voice note as the answer to the question they are holding.
#
#   RecordAnswer.new(question, message).call
#
# No matching logic is needed because of the one-at-a-time rule: whatever they
# send back is the answer to their single outstanding question. That is the
# whole reason the speaker's side can be a voice note and nothing else.
class RecordAnswer
  def initialize(question, message)
    @question = question
    @message = message
  end

  def call
    return false if already_recorded?

    attach_audio
    @question.mark_answered!(@message.id)
    notify_asker
    true
  rescue TransportError => e
    Rails.logger.error("RecordAnswer failed for Question##{@question.id}: #{e.message}")
    false
  end

  private

  # Both transports redeliver a webhook they did not hear a 200 for, so the same
  # voice note can arrive more than once.
  def already_recorded?
    @question.answer_message_id == @message.id ||
      Question.exists?(answer_message_id: @message.id)
  end

  def attach_audio
    @question.answer_audio.attach(
      io: StringIO.new(@message.download_audio),
      filename: "answer_#{@question.id}.ogg",
      content_type: "audio/ogg"
    )
  end

  def notify_asker
    QuestionMailer.answered(@question).deliver_later
  end
end
