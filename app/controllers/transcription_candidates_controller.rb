# frozen_string_literal: true

# Accepting or dismissing one line of a re-transcription (#133).
#
# PATCH with transcription_candidate[status] = accepted | dismissed. Accepting
# goes through Transcription::AcceptCandidate, so a confirmed entry is never
# changed and every change is a normal versioned update.
class TranscriptionCandidatesController < ApplicationController
  include TranscriptionReview

  def update
    @candidate = TranscriptionCandidate.includes(transcription_run: :voice_recording).find(params[:id])
    authorize @candidate
    @run = @candidate.transcription_run
    @error = resolve
    @seen_at = seen_at

    respond_to do |format|
      format.turbo_stream { render status: (@error ? :unprocessable_content : :ok) }
      format.html { redirect_to transcription_run_path(@run), @error ? {alert: @error} : {} }
    end
  end

  private

  def resolve
    case candidate_params[:status]
    when "accepted"
      service = Transcription::AcceptCandidate.new(@candidate, by: current_user, current_text: candidate_params[:current_text])
      service.error unless service.call
    when "dismissed"
      "This line has already been #{@candidate.status}." unless @candidate.dismiss(by: current_user)
    else
      "Choose whether to use the new text or keep the current one."
    end
  end

  def candidate_params
    params.require(:transcription_candidate).permit(:status, :current_text)
  end
end
