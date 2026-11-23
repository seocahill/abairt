# frozen_string_literal: true

module TranscriptionRuns
  # "Accept all" on a re-transcription (#133): the new text on every pending
  # differing line whose entry is unconfirmed. Confirmed lines and new lines
  # are left for a person to look at one by one.
  class AcceptancesController < ApplicationController
    include TranscriptionReview

    def create
      run = TranscriptionRun.find(params[:transcription_run_id])
      authorize run, :update?

      result = Transcription::AcceptAll.call(run, by: current_user, seen_at:, hide_cosmetic: params[:hide_cosmetic] == "1")
      notice = "Used the new text on #{helpers.pluralize(result[:accepted], "line")}."
      notice += " #{helpers.pluralize(result[:skipped], "line")} changed since you opened the page, so #{(result[:skipped] == 1) ? "it was" : "they were"} left for you to look at." if result[:skipped].positive?
      redirect_to transcription_run_path(run, hide_cosmetic: params[:hide_cosmetic].presence), notice:
    end
  end
end
