# frozen_string_literal: true

# Decides what a message arriving from a speaker means.
#
#   ProcessInbound.new(message).call
#
# There is no matching logic, because there is nothing to match: a speaker holds
# exactly one thing at a time — a question or a segment, never both — so what
# they send back can only be about that. See SpeakerSlot.
#
#   holding a question, a voice note   -> that is the answer
#   holding a segment, a voice note    -> that is what was actually said
#   holding a segment, the button      -> the transcription was right
#   holding nothing                    -> they are available, so send them
#                                         whatever is waiting
class ProcessInbound
  def initialize(message)
    @message = message
  end

  def call
    speaker = find_speaker
    return if speaker.nil?

    answer(speaker)

    # Questions first: a learner is waiting on those, where a segment is only
    # ever filling a quiet week. Whichever goes out takes the slot, so the
    # second call finds them busy and does nothing.
    QuestionQueue.new(speaker).deliver_next
    SegmentQueue.new(speaker).deliver_next
  end

  private

  # A sender we do not know is routine: following an invite link is how a
  # speaker first appears, so this may resolve to one.
  def find_speaker
    @message.speaker || @message.onboard
  end

  def answer(speaker)
    holding = SpeakerSlot.new(speaker).outstanding

    case holding
    when Question
      RecordAnswer.new(holding, @message).call if @message.audio?
    when SegmentPrompt
      answer_segment(holding)
    end
  end

  # Anything that is neither the mic nor the button is left alone — they may
  # just be saying hello, and the segment stays out with them.
  def answer_segment(prompt)
    if @message.audio?
      prompt.record_correction!(@message)
    elsif @message.text.strip == Telegram::DeliverSegment::CONFIRM
      prompt.confirm!
    end
  end
end
