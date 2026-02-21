class TranscriptAnalysisJob < ApplicationJob
  queue_as :default

  def perform
    recording = VoiceRecording
      .joins(:dictionary_entries)
      .where(metadata_analysis: nil)
      .distinct.last

    TranscriptAnalysisService.new(recording).analyze
  end
end
