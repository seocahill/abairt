# frozen_string_literal: true

# Backfill metadata for all voice recordings that have translations
# but haven't been processed yet.
#
# Usage:
#   BackfillVoiceRecordingMetadataJob.perform_later
#   BackfillVoiceRecordingMetadataJob.perform_later(batch_size: 50)
#
class BackfillVoiceRecordingMetadataJob < ApplicationJob
  queue_as :default

  def perform(batch_size: 100)
    recordings = VoiceRecording
      .where(metadata_extracted_at: nil)
      .joins(:dictionary_entries)
      .where.not(dictionary_entries: { translation: [nil, ""] })
      .distinct

    total = recordings.count
    Rails.logger.info("BackfillVoiceRecordingMetadataJob: Processing #{total} recordings")

    recordings.find_each.with_index do |recording, index|
      Rails.logger.info("Processing #{index + 1}/#{total}: VoiceRecording##{recording.id}")

      ExtractVoiceRecordingMetadataJob.perform_later(recording.id)

      # Small delay to avoid hammering OpenAI API
      sleep(0.5) if (index + 1) % batch_size == 0
    end

    Rails.logger.info("BackfillVoiceRecordingMetadataJob: Queued #{total} recordings for processing")
  end
end
