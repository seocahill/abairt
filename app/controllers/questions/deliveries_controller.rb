# frozen_string_literal: true

module Questions
  # Sending a draft is its own resource rather than a verb on the question, in
  # the same shape as voice_recordings/diarizations.
  # Admins only while the feature is in beta, as with QuestionsController.
  class DeliveriesController < ApplicationController
    before_action :require_login
    before_action :ensure_admin

    def create
      @question = current_user.questions.find(params[:question_id])
      authorize @question, :update?

      if @question.send_to_speaker!
        # Nobody connected yet simply means it waits: it is in the queue,
        # and the first speaker to arrive picks it up through the ordinary
        # path in ProcessInbound. A draft that already names a speaker is one
        # recorded before the speaker was chosen at delivery, so it keeps them.
        speaker = @question.speaker || QuestionRouter.new.speaker
        DeliverNextQuestionJob.perform_later(speaker) if speaker
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
