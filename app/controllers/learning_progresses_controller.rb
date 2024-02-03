class LearningProgressesController < ApplicationController
  def show
    @learning_progress = LearningProgress.find(params[:id])

    authorize(@learning_progress)
  end

  # In LearningProgressesController
  def update
    @learning_progress = LearningProgress.find(params[:id])
    quality_rating = params[:quality]

    authorize(@learning_progress)

    spaced_repetition_service = SpacedRepetitionService.new(@learning_progress, quality_rating)
    result = spaced_repetition_service.calculate_interval

    if result == "done"
      @learning_progress.update(completed: true)
    else
      @learning_progress.update(interval: result, next_review_date: Date.today + result, last_review_date: Date.today)
    end

    if next_progress = @learning_progress.learning_session.current_or_new_learning_progress(@learning_progress.id)
      redirect_to learning_progress_path(next_progress)
    else
      redirect_to root_path, notice: "Done for now"
    end
  end

  private

  def show_next_learning_progress_path(learning_session)
    # Define the logic to find the next learning progress for the given learning session
    # Example:
    next_progress = learning_session.current_or_new_learning_progress
    learning_progress_path(next_progress)
  end
end
