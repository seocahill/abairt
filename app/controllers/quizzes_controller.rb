class QuizzesController < ApplicationController
  # before_action :authenticate,/_user!

  def index
    @quizzes = current_user.quizzes
    authorize @quizzes
  end

  def show
    @quiz = Quiz.find(params[:id])
    authorize @quiz

    # Get the current or next quiz item for this quiz
    @quiz_item = @quiz.current_or_next_item

    if @quiz_item.nil?
      redirect_to quizzes_path, notice: "You've completed all items in this quiz!"
    end
  end

  def new
    @quiz = Quiz.new
    authorize @quiz
  end

  def create
    @quiz = Quiz.new(quiz_params)
    @quiz.user = current_user

    authorize @quiz

    if @quiz.save
      redirect_to @quiz, notice: "Quiz was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def quiz_params
    params.require(:quiz).permit(:name, :description, :dictionary_entry_ids => [])
  end
end
