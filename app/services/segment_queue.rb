# frozen_string_literal: true

# One segment at a time, per speaker.
#
#   SegmentQueue.new(speaker).deliver_next
#
# The same rule as QuestionQueue and, deliberately, the same slot: a speaker
# holds one thing, of either kind. Questions come first — somebody is waiting on
# those — and segments are what fills a quiet week.
#
# Only segments from recordings the speaker has claimed. The claim decides whose
# Telegram the prompts go to and nothing else: anybody may still translate any
# recording in the web app.
class SegmentQueue
  def initialize(speaker)
    @speaker = speaker
  end

  def deliver_next
    return unless SpeakerSlot.new(@speaker).free?
    return if questions_waiting?

    entry = next_entry
    return if entry.nil?

    deliver(entry)
  end

  private

  # A segment never goes out ahead of a question that has not been sent yet.
  def questions_waiting?
    Question.waiting.where(speaker: [nil, @speaker]).exists?
  end

  # Unchecked, has audio to send, from one of their own recordings, and not
  # already asked about. In the order they were spoken, so the recording is
  # worked through rather than jumped around.
  def next_entry
    DictionaryEntry
      .unconfirmed_accuracy
      .has_recording
      .where(voice_recording: @speaker.claimed_voice_recordings)
      .where.missing(:segment_prompts)
      .order(:region_start)
      .first
  end

  # Sent before the prompt is recorded, as QuestionQueue does: a message that
  # went out with no record of it means the segment is simply offered again,
  # where a record with no message would hold the slot shut for ever.
  def deliver(entry)
    message_id = Telegram::DeliverSegment.new(entry, @speaker).call
    return if message_id.nil?

    SegmentPrompt.create!(
      dictionary_entry: entry,
      speaker: @speaker,
      sent_at: Time.current,
      message_id: message_id
    )
  end
end
