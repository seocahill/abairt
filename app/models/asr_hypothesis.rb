# frozen_string_literal: true

# A provider's raw ASR output for an entry, kept so human corrections later
# become evaluation data. Never shown to listeners.
class AsrHypothesis < ApplicationRecord
  belongs_to :dictionary_entry

  validates :provider, :text, presence: true

  # Keeps the raw output of a transcription without ever raising into the
  # import pipeline that called it.
  def self.record(entry, provider:, text:, model: nil)
    return if text.blank? || entry.blank? || !entry.persisted?

    create(dictionary_entry: entry, provider: provider, model: model, text: text)
  rescue => e
    Rails.logger.error("Could not keep #{provider} hypothesis: #{e.message}")
    nil
  end
end
