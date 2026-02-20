# frozen_string_literal: true

# Corrects dictionary entry transcriptions using the full transcript on the
# VoiceRecording, then re-translates any entries that were updated.
class AutocorrectTranscriptionsJob < ApplicationJob
  queue_as :default

  def perform(voice_recording_id)
    voice_recording = VoiceRecording.find(voice_recording_id)

    updated_count = AutocorrectTranscriptionsService.new(voice_recording).process
    return unless updated_count&.positive?

    Rails.logger.info("AutocorrectTranscriptionsJob: corrected #{updated_count} entries for recording #{voice_recording_id}, re-translating")

    voice_recording.dictionary_entries
      .where(accuracy_status: :unconfirmed, translation: [nil, ""])
      .order(:region_start)
      .each(&:translate)
  end
end
