# frozen_string_literal: true

module TranscriptionRuns
  # "Accept all" on a re-transcription (#133): the new text on every pending
  # differing line whose entry is unconfirmed. Confirmed lines and new lines
  # are left for a person to look at one by one.
  class AcceptancesController < ApplicationController
    include RetranscribeFlag

    def create
      run = TranscriptionRun.find(params[:transcription_run_id])
      authorize run, :update?

      accepted = Transcription::AcceptAll.call(run, by: current_user)
      redirect_to transcription_run_path(run), notice: "Used the new text on #{helpers.pluralize(accepted, "line")}."
    end
  end
end
