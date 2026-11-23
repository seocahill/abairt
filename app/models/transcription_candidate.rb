# frozen_string_literal: true

# A line of new ASR text from a transcription run (#133), waiting for a person
# to accept or dismiss it.
#
# `differs`: it lines up with a current entry and its text is different.
# `new_segment`: it lines up with no current entry. It keeps the segment's
# Fotheidil id and speaker label so it can later be added as an entry the same
# way the import pipeline does.
#
# Nothing here changes an entry: accepting goes through the entry's own
# versioned update.
class TranscriptionCandidate < ApplicationRecord
  belongs_to :transcription_run
  belongs_to :dictionary_entry, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  enum :kind, {differs: 0, new_segment: 1}
  enum :status, {pending: 0, accepted: 1, dismissed: 2}

  validates :word_or_phrase, presence: true
  validates :region_start, numericality: {greater_than_or_equal_to: 0}
  validates :region_end, numericality: true
  validates :dictionary_entry, presence: true, if: :differs?
  validates :dictionary_entry_id, uniqueness: {scope: :transcription_run_id}, allow_nil: true
  validates :resolved_by, :resolved_at, presence: true, unless: :pending?
  validates :resolved_by, :resolved_at, absence: true, if: :pending?
  validate :ends_after_it_starts
  validate :entry_from_the_same_recording

  private

  def ends_after_it_starts
    return if region_start.blank? || region_end.blank?

    errors.add(:region_end, "must be after the start") unless region_end > region_start
  end

  def entry_from_the_same_recording
    return if dictionary_entry.blank? || transcription_run.blank?
    return if dictionary_entry.voice_recording_id == transcription_run.voice_recording_id

    errors.add(:dictionary_entry, "must belong to the run's recording")
  end
end
