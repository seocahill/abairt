# frozen_string_literal: true

module TranscriptionRuns
  # "Set all timing" on a re-transcription (#133): every pending line that has
  # no times gets the times found for it. Text is never touched, and a line
  # that has times by now is left as it is.
  class TimingsController < ApplicationController
    include TranscriptionReview

    def create
      run = TranscriptionRun.find(params[:transcription_run_id])
      authorize run, :update?

      result = Transcription::AcceptAll.call(run, by: current_user, seen_at:, kind: :timing)
      redirect_to transcription_run_path(run, hide_cosmetic: params[:hide_cosmetic].presence),
        notice: "Gave times to #{helpers.pluralize(result[:accepted], "line")}."
    end
  end
end
