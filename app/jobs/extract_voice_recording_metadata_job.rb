# frozen_string_literal: true

class ExtractVoiceRecordingMetadataJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id)
    voice_recording = VoiceRecording.find(voice_recording_id)

    # Skip if already processed recently (within last 24 hours)
    if voice_recording.metadata_extracted_at.present? &&
       voice_recording.metadata_extracted_at > 24.hours.ago
      Rails.logger.info("Skipping metadata extraction for VoiceRecording##{voice_recording_id} - already processed")
      return
    end

    # Skip if no transcribed entries yet
    unless voice_recording.dictionary_entries.where.not(translation: [nil, ""]).exists?
      Rails.logger.info("Skipping metadata extraction for VoiceRecording##{voice_recording_id} - no translations available")
      return
    end

    VoiceRecordingMetadataService.new(voice_recording).process
  end
end
