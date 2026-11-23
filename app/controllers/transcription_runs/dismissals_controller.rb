# frozen_string_literal: true

module TranscriptionRuns
  # "Dismiss run" (#133): every line still waiting is dismissed and the
  # recording stays exactly as it is.
  class DismissalsController < ApplicationController
    include TranscriptionReview

    def create
      run = TranscriptionRun.includes(:voice_recording).find(params[:transcription_run_id])
      authorize run, :update?

      dismissed = run.dismiss_pending(by: current_user)
      redirect_to voice_recording_path(run.voice_recording), notice: "Re-transcription dismissed (#{helpers.pluralize(dismissed, "line")}). Nothing was changed."
    end
  end
end
