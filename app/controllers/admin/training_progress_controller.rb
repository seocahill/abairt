# frozen_string_literal: true

module Admin
  # Read-only report of checked hours per speaker against the training-data targets.
  class TrainingProgressController < ApplicationController
    before_action :ensure_admin
    skip_after_action :verify_authorized

    def index
      @progress = TrainingData::Progress.call
      @recordings = VoiceRecording.where(id: @progress[:needs_work].pluck(:voice_recording_id)).index_by(&:id)
    end
  end
end
