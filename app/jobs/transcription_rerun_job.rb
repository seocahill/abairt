# frozen_string_literal: true

# Runs a re-transcription of a recording (#133) into its TranscriptionRun.
# The work is in Transcription::RerunOperation.
class TranscriptionRerunJob < ApplicationJob
  queue_as :default

  # One Fotheidil job at a time, shared with ProcessFotheidilVideoJob, so a
  # re-run doesn't pile onto Abair. A run waits up to 30 minutes on its
  # transcript, so hold the slot long enough to cover it.
  limits_concurrency to: 1, key: "fotheidil_browser", group: "fotheidil", duration: 1.hour

  discard_on ActiveRecord::RecordNotFound

  def perform(transcription_run_id)
    run = TranscriptionRun.find(transcription_run_id)
    return unless run.pending? # enqueued twice, or already finished

    result = Transcription::RerunOperation.call(transcription_run: run)
    return if result.success?

    NotificationsMailer.transcription_failed(run.voice_recording, "Re-transcription: #{result[:error]}").deliver_later
  end
end
