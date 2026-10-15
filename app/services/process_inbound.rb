# frozen_string_literal: true

# Decides what a message arriving from a speaker means.
#
#   ProcessInbound.new(message).call
#
# There are only two possibilities, and the speaker never has to signal which
# one they mean:
#
#   * a voice note while holding a question  -> that is the answer
#   * anything else (a button tap, a hello)  -> they are available, so send
#                                               them whatever is waiting
class ProcessInbound
  def initialize(message)
    @message = message
  end

  def call
    speaker = find_speaker
    return if speaker.nil?

    record_answer(speaker) if @message.audio?
    QuestionQueue.new(speaker).deliver_next
  end

  private

  # A sender we do not know is routine: following an invite link is how a
  # speaker first appears, so this may resolve to one.
  def find_speaker
    @message.speaker || @message.onboard
  end

  def record_answer(speaker)
    question = QuestionQueue.new(speaker).outstanding
    return if question.nil?

    RecordAnswer.new(question, @message).call
  end
end
