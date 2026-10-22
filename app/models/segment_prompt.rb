# frozen_string_literal: true

# One segment of a recording, sent to one speaker to be checked.
#
#   SegmentPrompt.outstanding_for(speaker)
#
# Two ways back. They tap the button, meaning the transcription was right as it
# stood, and the entry is confirmed. Or they hold the mic and say what was
# actually said — which is not an edit anybody can apply automatically, so the
# entry stays unconfirmed and the prompt is `corrected`: somebody still has to
# write the correction down. `SegmentPrompt.to_apply` is that queue.
class SegmentPrompt < ApplicationRecord
  belongs_to :dictionary_entry
  belongs_to :speaker, class_name: "User"

  has_one_attached :correction_audio

  enum :status, {sent: 0, confirmed: 1, corrected: 2}

  scope :oldest_first, -> { order(created_at: :asc) }
  scope :to_apply, -> { corrected }

  def self.outstanding_for(speaker)
    sent.where(speaker: speaker).oldest_first.first
  end

  # The transcription was right. This is the cheap path, and the one that
  # produces finished work rather than a queue item.
  def confirm!
    transaction do
      update!(status: :confirmed, answered_at: Time.current)
      dictionary_entry.update!(accuracy_status: :confirmed)
    end
  end

  # They said what it should be instead. The entry is deliberately left
  # unconfirmed: a voice note is an annotation, not a correction anything here
  # can apply, and marking it confirmed would hide that work still remains.
  def record_correction!(message)
    # Telegram redelivers anything it did not get a 200 for, so the same voice
    # note can arrive twice.
    return false if correction_audio.attached?

    attach_correction(message)
    update!(status: :corrected, answered_at: Time.current)
    true
  end

  private

  # `identify: false` for the same reason as RecordAnswer: Active Storage
  # re-sniffs the bytes and relabels a voice note `audio/opus`, which no browser
  # advertises as playable. Telegram sends ogg/opus by specification.
  def attach_correction(message)
    correction_audio.attach(
      io: StringIO.new(message.download_audio),
      filename: "correction_#{id}.ogg",
      content_type: "audio/ogg",
      identify: false
    )
  end
end
