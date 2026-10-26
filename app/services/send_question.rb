# frozen_string_literal: true

# Sends a draft question: it joins the queue, and the speaker it is routed to
# is asked to take their next one. With nobody connected it simply waits, and
# the first speaker to arrive picks it up.
#
#   SendQuestion.new(question).call # => false if it was not a draft
class SendQuestion
  def initialize(question)
    @question = question
  end

  def call
    return false unless @question.send_to_speaker!

    # A draft that already names a speaker keeps them.
    speaker = @question.speaker || QuestionRouter.new.speaker
    DeliverNextQuestionJob.perform_later(speaker) if speaker
    true
  end
end
