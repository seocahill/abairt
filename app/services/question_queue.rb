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

  # Spans both kinds: a speaker holding a segment is not free for a question
  # either, or a voice note coming back would be ambiguous. See SpeakerSlot.
  def outstanding?
    !SpeakerSlot.new(@speaker).free?
  end

  # Questions with no speaker are the pool every free speaker draws from:
  # one recorded before anybody was connected belongs to whoever arrives
  # first. Their own waiting questions are considered alongside it, oldest
  # of either wins.
  def next_waiting
    Question.waiting.where(speaker: [nil, @speaker]).oldest_first.first
  end

  def deliver(question)
    # Claimed on the way out, which is the only point at which we know who
    # is actually free to take it.
    question.update!(speaker: @speaker) if question.speaker.nil?

    message_id = Telegram::DeliverQuestion.new(question).call
    question.mark_sent!(message_id) if message_id
  end
end
