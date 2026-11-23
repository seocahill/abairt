# frozen_string_literal: true

# A line of new ASR text from a transcription run (#133), waiting for a person
# to accept or dismiss it.
#
# `differs`: it lines up with a current entry and its text is different.
# `new_segment`: it lines up with no current entry. It keeps the segment's
# Fotheidil id and speaker label so it can later be added as an entry the same
# way the import pipeline does.
# `timing`: the entry has no times (its text was typed in or copied from
# elsewhere) and the new transcription says where it is spoken. The region is
# the proposed time; the text stays the entry's own.
#
# Nothing here changes an entry: accepting goes through the entry's own
# versioned update.
class TranscriptionCandidate < ApplicationRecord
  belongs_to :transcription_run
  belongs_to :dictionary_entry, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  enum :kind, {differs: 0, new_segment: 1, timing: 2}
  enum :status, {pending: 0, accepted: 1, dismissed: 2}

  validates :word_or_phrase, presence: true
  validates :region_start, numericality: {greater_than_or_equal_to: 0}
  validates :region_end, numericality: true
  validates :dictionary_entry, presence: true, if: -> { differs? || timing? }
  validates :dictionary_entry_id, uniqueness: {scope: [:transcription_run_id, :kind]}, allow_nil: true
  validates :resolved_by, :resolved_at, presence: true, unless: :pending?
  validates :resolved_by, :resolved_at, absence: true, if: :pending?
  validate :ends_after_it_starts
  validate :entry_from_the_same_recording

  scope :in_time_order, -> { order(:region_start, :id) }
  # What "Accept all" covers: differing lines on entries nobody has confirmed.
  scope :acceptable_in_bulk, -> { pending.differs.joins(:dictionary_entry).merge(DictionaryEntry.unconfirmed_accuracy) }

  scope :timing_in_bulk, -> { pending.timing }

  # The ids, among `entries`, of those whose Irish was replaced by an accepted
  # candidate and still reads so, while their translation has stayed as it was
  # then and nobody has confirmed the line since.
  def self.stale_translation_entry_ids(entries)
    accepted.differs.where(dictionary_entry: entries)
      .joins(:dictionary_entry)
      .merge(DictionaryEntry.unconfirmed_accuracy)
      .where("dictionary_entries.word_or_phrase = transcription_candidates.word_or_phrase")
      .where("dictionary_entries.translation = transcription_candidates.translation_at_acceptance")
      .where.not(translation_at_acceptance: [nil, ""])
      .distinct
      .pluck(:dictionary_entry_id)
      .to_set
  end

  # The new text reads the same as the entry's, but for case or punctuation.
  def cosmetic?
    differs? && Transcription::Text.cosmetic_difference?(dictionary_entry.word_or_phrase, word_or_phrase)
  end

  def dismiss(by:)
    return false unless pending?

    update(status: :dismissed, resolved_by: by, resolved_at: Time.current)
  end

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
