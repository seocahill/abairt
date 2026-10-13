# frozen_string_literal: true

module Questions
  # Sending a draft is its own resource rather than a verb on the question, in
  # the same shape as voice_recordings/diarizations.
  class DeliveriesController < ApplicationController
    before_action :require_login

    def create
      @question = current_user.questions.find(params[:question_id])
      authorize @question, :update?

      if @question.send_to_speaker!
        DeliverNextQuestionJob.perform_later(@question.speaker)
      end

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@question, partial: "questions/question", locals: {question: @question}) }
        format.html { redirect_to new_question_path, notice: "Seolta. Gheobhaidh tú freagra go luath." }
      end
    end

    private

    def require_login
      redirect_to login_path, alert: "Caithfidh tú a bheith sínithe isteach!" unless current_user
    end
  end
end
