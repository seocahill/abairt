# frozen_string_literal: true

# The learner's side: record a question, hear the answer when it comes back.
#
# `new` is the installed-to-home-screen screen — one button, held down. It is
# also the PWA's start_url, so opening the app lands straight on it.
#
# **Admins only, for now.** Asking a question spends a real person's time and,
# once payments exist, real money, and none of it has been through anyone but
# us. Lifting this is one line here and one in QuestionPolicy — deliberately
# two, so neither alone opens it by accident.
class QuestionsController < ApplicationController
  before_action :require_login
  before_action :ensure_admin

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
    # No speaker here on purpose: one is chosen when the question is sent,
    # so recording works whether or not anybody is connected yet.
    @question = Question.new(asker: current_user)
    @question.audio.attach(params[:audio]) if params[:audio].present?
    authorize @question

    # Saved as a draft, not sent. The learner listens back first — a recording
    # made one-handed is often not the question they meant to ask, and once a
    # question costs credits, sending unheard is the wrong default.
    if @question.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to new_question_path, notice: "Taifeadta. Éist leis sula seolann tú é." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html do
          @speaker = QuestionRouter.new.speaker
          @questions = recent_questions.limit(10)
          render :new, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    question = current_user.questions.find(params[:id])
    authorize question
    question.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(question) }
      format.html { redirect_to new_question_path, notice: "Scriosta." }
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
