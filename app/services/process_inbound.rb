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
#
# Identical on both transports, because the only things that differ — who the
# sender is, how to fetch their audio, what an unknown sender means — are
# answered by the message object itself.
class ProcessInbound
  def initialize(message)
    @message = message
  end

  def call
    speaker = find_speaker
    return if speaker.nil?

    # Recorded before anything decides whether it can send: on WhatsApp this is
    # what reopens the 24 hour window.
    @message.note_inbound(speaker)

    record_answer(speaker) if @message.audio?
    QuestionQueue.new(speaker).deliver_next
  end

  private

  # A sender we do not know is routine on Telegram, where tapping Start is how a
  # speaker first appears, and a dead end on WhatsApp. The channel decides, and
  # may resolve to a speaker.
  def find_speaker
    @message.speaker || @message.onboard
  end

  def record_answer(speaker)
    question = QuestionQueue.new(speaker).outstanding
    return if question.nil?

    RecordAnswer.new(question, @message).call
  end
end
