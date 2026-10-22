# frozen_string_literal: true

# What a speaker is holding right now, of either kind.
#
#   SpeakerSlot.new(speaker).free?
#
# The one-at-a-time rule spans questions and segments together, and has to: a
# voice note coming back carries no id and no keyword, so it can only be read as
# an answer to the single thing the speaker is holding. Let them hold a question
# and a segment at once and that stops being true.
#
# Questions win when both are available. They are the thing learners are waiting
# on; segments are what fills a quiet week.
class SpeakerSlot
  def initialize(speaker)
    @speaker = speaker
  end

  def outstanding
    question || segment_prompt
  end

  def free?
    outstanding.nil?
  end

  def question
    @speaker.asked_questions.sent.oldest_first.first
  end

  def segment_prompt
    SegmentPrompt.outstanding_for(@speaker)
  end
end
