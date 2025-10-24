class FotheidilFixerJob < ApplicationJob
  queue_as :default

  def perform
    # Find the most recent VoiceRecording that needs fixing, in priority order:
    # 1. Has video_id but missing segments (transcription incomplete)
    # 2. Has segments but incomplete entries (entry creation incomplete)
    # 3. Has media but no video_id (upload failed)

    voice_recording = VoiceRecording
      .joins(:media_attachment)
      .where(diarization_status: ['processing', 'failed', nil])
      .order(created_at: :desc)
      .find do |vr|
        # Priority 1: Has video ID but missing segments
        next true if vr.fotheidil_video_id.present? && vr.segments.blank?

        # Priority 2: Has segments but incomplete entries
        next true if vr.segments.present? && vr.dictionary_entries_count < vr.segments.count

        # Priority 3: Has media but no video ID
        next true if vr.fotheidil_video_id.blank? && vr.dictionary_entries_count.zero?

        false
      end

    return unless voice_recording

    Rails.logger.info "FotheidilFixerJob retrying VoiceRecording #{voice_recording.id}"

    # Retry processing with the existing fotheidil_video_id (or nil to trigger upload)
    ProcessFotheidilVideoJob.perform_later(voice_recording.id, voice_recording.fotheidil_video_id)
  end
end
