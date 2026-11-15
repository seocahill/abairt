# frozen_string_literal: true

module Admin
  # Read-only report of ASR quality (WER/CER) on the frozen evaluation set.
  class AsrController < ApplicationController
    before_action :ensure_admin
    before_action :ensure_flag_enabled
    skip_after_action :verify_authorized

    def index
      @eval_set = AsrEvalSet.order(:created_at).last
      @runs = @eval_set ? latest_runs_by_provider(@eval_set) : []
      @trend = @eval_set ? @eval_set.asr_eval_runs.order(:created_at).last(20) : []
      @candidates = candidate_counts
    end

    private

    def ensure_flag_enabled
      raise ActionController::RoutingError, "Not Found" unless Flipper.enabled?(:f75_asr_eval, current_user)
    end

    def latest_runs_by_provider(eval_set)
      eval_set.asr_eval_runs.order(created_at: :desc).limit(50).group_by(&:provider).values.map(&:first)
    end

    # How many segments currently qualify as ground truth, by speaker.
    def candidate_counts
      DictionaryEntry.asr_eval_candidates.joins(:speaker).group("users.name").order(Arel.sql("COUNT(*) DESC")).count
    end
  end
end
