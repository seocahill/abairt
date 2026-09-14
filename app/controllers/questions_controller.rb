# frozen_string_literal: true

# The learner's side: record a question, see the answer when it comes back.
class QuestionsController < ApplicationController
  before_action :require_login

  def index
    @questions = current_user.questions.includes(:speaker).order(created_at: :desc)
  end

  def show
    @question = current_user.questions.find(params[:id])
  end

  def new
    @question = Question.new
    authorize @question
    @speaker = QuestionRouter.new.speaker
  end

  def create
    @question = Question.new(asker: current_user, speaker: QuestionRouter.new.speaker)
    @question.audio.attach(params[:audio]) if params[:audio].present?
    authorize @question

    if @question.save
      DeliverNextQuestionJob.perform_later(@question.speaker)
      redirect_to questions_path, notice: "Seolta. Gheobhaidh tú freagra go luath."
    else
      @speaker = @question.speaker
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_login
    redirect_to login_path, alert: "Caithfidh tú a bheith sínithe isteach!" unless current_user
  end
end
