# frozen_string_literal: true

# Starting a fresh transcription of a recording, and the page for reviewing
# what came back (#133). Nothing here changes an entry: each candidate is
# accepted or dismissed through TranscriptionCandidatesController.
class TranscriptionRunsController < ApplicationController
  include TranscriptionReview

  def create
    recording = VoiceRecording.find(params[:voice_recording_id])
    run = recording.transcription_runs.new(requested_by: current_user)
    authorize run
    return redirect_to recording, alert: "This recording has no audio to send." unless recording.media.attached?

    recording.transcription_runs.abandoned.each(&:abandon!)
    if run.save
      TranscriptionRerunJob.perform_later(run.id)
      redirect_to recording, notice: "Re-transcription started. It can take up to half an hour; nothing changes until you review it."
    else
      redirect_to recording, alert: run.errors.full_messages.to_sentence
    end
  end

  def show
    @run = TranscriptionRun.includes(:voice_recording).find(params[:id])
    authorize @run
    @recording = @run.voice_recording
    @candidates = @run.transcription_candidates.includes(dictionary_entry: {media_attachment: :blob}).in_time_order
    @seen_at = Time.current
    @stale_translation_ids = TranscriptionCandidate.stale_translation_entry_ids(@candidates.filter_map(&:dictionary_entry))
  end
end
