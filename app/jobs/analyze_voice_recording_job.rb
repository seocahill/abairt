# frozen_string_literal: true

# Analyzes a voice recording's transcript to extract location and speaker metadata.
# Can be triggered manually or as part of the post-processing pipeline.
#
class AnalyzeVoiceRecordingJob < ApplicationJob
  queue_as :default

  def perform(voice_recording)
    return if voice_recording.dictionary_entries.empty?

    # Skip if already analyzed recently (within 24 hours)
    if voice_recording.metadata_analysis.present?
      analyzed_at = voice_recording.metadata_analysis["analyzed_at"]
      if analyzed_at.present? && Time.parse(analyzed_at) > 24.hours.ago
        Rails.logger.info("Skipping analysis for VoiceRecording##{voice_recording.id} - analyzed recently")
        return
      end
    end

    result = TranscriptAnalysisService.new(voice_recording).analyze

    if result[:skipped]
      Rails.logger.info("Analysis skipped for VoiceRecording##{voice_recording.id}: #{result[:reason]}")
    else
      Rails.logger.info("Analyzed VoiceRecording##{voice_recording.id}: " \
                        "#{result[:locations].size} locations, " \
                        "#{result[:speakers].size} speakers, " \
                        "dialect: #{result[:dialect_region]}")
    end
  end
end
