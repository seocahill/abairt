class SpacedRepetitionService
  MAX_INTERVAL = 365 # Example: 365 days

  def initialize(learning_progress, quality_rating)
    @learning_progress = learning_progress
    @quality = quality_rating.to_i
  end

  def calculate_interval
    if @quality >= 3
      if @learning_progress.repetition_number == 0
        @interval = 1
      elsif @learning_progress.repetition_number == 1
        @interval = 6
      else
        @interval = (@learning_progress.interval * @learning_progress.ease_factor).round
      end
      @learning_progress.repetition_number += 1
    else
      @learning_progress.repetition_number = 0
      @interval = 1
    end

    update_ease_factor

    # Check if the interval exceeds the maximum threshold
    if @interval > MAX_INTERVAL
      "done"
    else
      @interval
    end
  end

  private

  def update_ease_factor
    new_ease_factor = @learning_progress.ease_factor + (0.1 - (5 - @quality) * (0.08 + (5 - @quality) * 0.02))
    @learning_progress.ease_factor = [new_ease_factor, 1.3].max
  end
end
