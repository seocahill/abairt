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
  rescue Telegram::Client::Error => e
    Rails.logger.error("RecordAnswer failed for Question##{@question.id}: #{e.message}")
    false
  end

  private

  # Telegram redelivers anything it did not get a 200 for, so the same voice
  # note can arrive more than once.
  def already_recorded?
    @question.answer_message_id == @message.id ||
      Question.exists?(answer_message_id: @message.id)
  end

  # `identify: false` because Active Storage otherwise re-sniffs the bytes and
  # relabels a voice note `audio/opus`, which is not a container type any
  # browser advertises: canPlayType("audio/opus") is "" where
  # canPlayType("audio/ogg; codecs=opus") is "probably". Chromium sniffs and
  # plays it anyway, Safari is stricter, and the learner's side is a phone.
  # Telegram sends ogg/opus by specification, so the declared type is right and
  # the sniffed one is not.
  def attach_audio
    @question.answer_audio.attach(
      io: StringIO.new(@message.download_audio),
      filename: "answer_#{@question.id}.ogg",
      content_type: "audio/ogg",
      identify: false
    )
  end

  # Apps asking through the API show the answer themselves, and their API user
  # is not the person who asked.
  def notify_asker
    QuestionMailer.answered(@question).deliver_later if @question.asked_via == "abairt"
  end
end
