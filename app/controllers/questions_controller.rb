# frozen_string_literal: true

# The learner's side: record a question, hear the answer when it comes back.
#
# `new` is the installed-to-home-screen screen — one button, held down. It is
# also the PWA's start_url, so opening the app lands straight on it.
class QuestionsController < ApplicationController
  before_action :require_login

  def index
    @questions = recent_questions.limit(100)
  end

  def show
    @question = current_user.questions.find(params[:id])
  end

  def new
    @question = Question.new
    authorize @question
    @speaker = QuestionRouter.new.speaker
    @questions = recent_questions.limit(10)
  end

  def create
    @question = Question.new(asker: current_user, speaker: QuestionRouter.new.speaker)
    @question.audio.attach(params[:audio]) if params[:audio].present?
    authorize @question

    if @question.save
      DeliverNextQuestionJob.perform_later(@question.speaker)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to new_question_path, notice: "Seolta. Gheobhaidh tú freagra go luath." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html do
          @speaker = @question.speaker
          @questions = recent_questions.limit(10)
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def recent_questions
    current_user.questions.includes(:speaker).with_attached_answer_audio.order(created_at: :desc)
  end

  def require_login
    redirect_to login_path, alert: "Caithfidh tú a bheith sínithe isteach!" unless current_user
  end
end
