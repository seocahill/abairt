# frozen_string_literal: true

module Admin
  # The backlog, for the founder. The speaker never sees any of this.
  class QuestionsController < ApplicationController
    include Pagy::Backend

    before_action :ensure_admin
    skip_after_action :verify_authorized

    def index
      scope = Question.includes(:asker, :speaker).order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?

      @pagy, @questions = pagy(scope, items: 25)
      @stats = Question.group(:status).count.symbolize_keys
      @speakers = User.answering
    end

    # Nudges the queue by hand when something has got stuck.
    def deliver
      speaker = Question.find(params[:id]).speaker || QuestionRouter.new.speaker
      if speaker.nil?
        return redirect_to admin_questions_path, alert: "Níl aon chainteoir ceangailte fós."
      end

      QuestionQueue.new(speaker).deliver_next

      redirect_to admin_questions_path, notice: "Sheiceáil muid an scuaine do #{speaker.name}."
    end
  end
end
