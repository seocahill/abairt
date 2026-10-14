# frozen_string_literal: true

# One question at a time, per speaker.
#
# Everything the speaker experiences follows from this rule. They never receive
# a second question until they have answered the first, so their reply is
# always unambiguously the answer to the one question they are holding.
#
#   QuestionQueue.new(speaker).deliver_next
#
# Safe to call whenever anything might have changed (a question arrived, an
# answer came back, an admin nudged it). It does nothing if the speaker already
# has one out with them, and nothing if there is nothing waiting.
class QuestionQueue
  def initialize(speaker)
    @speaker = speaker
  end

  def deliver_next
    return if outstanding?

    question = next_waiting
    return if question.nil?

    deliver(question)
    question
  end

  def outstanding
    @speaker.asked_questions.sent.oldest_first.first
  end

  private

  def outstanding?
    outstanding.present?
  end

  def next_waiting
    @speaker.asked_questions.waiting.oldest_first.first
  end

  def deliver(question)
    message_id = QuestionTransport.for(question).call
    question.mark_sent!(message_id) if message_id
  end
end
