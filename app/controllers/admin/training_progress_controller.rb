# frozen_string_literal: true

module Admin
  # Read-only report of checked hours per speaker against the training-data targets.
  class TrainingProgressController < ApplicationController
    before_action :ensure_admin
    before_action :ensure_flag_enabled
    skip_after_action :verify_authorized

    def index
      @progress = TrainingData::Progress.call
      @recordings = VoiceRecording.where(id: @progress[:needs_work].pluck(:voice_recording_id)).index_by(&:id)
    end

    private

    def ensure_flag_enabled
      raise ActionController::RoutingError, "Not Found" unless Flipper.enabled?(:f142_training_progress, current_user)
    end
  end
end
