#
# The Repetition module uses the Super Memo method to determine when to next
# review an item. The quality values are as follows:
#
# 5 - perfect response
# 4 - correct response after a hesitation
# 3 - correct response recalled with serious difficulty
# 2 - incorrect response; where the correct one seemed easy to recall
# 1 - incorrect response; the correct one remembered
# 0 - complete blackout
#
# Find out more here: https://www.supermemo.com/english/ol/sm2.htm
#

require "date"

class SuperMemoService
  def initialize(quality_response, prev_interval = 0, prev_ef = 2.5)
    @prev_ef = prev_ef
    @prev_interval = prev_interval
    @quality_response = quality_response

    @calculated_interval = nil
    @calculated_ef = nil
    @repetition_date = nil

    #if quality_response is below 3 start repetition from the begining, but without changing easiness_factor
    if @quality_response < 3
      @calculated_ef = @prev_ef
      @calculated_interval = 0
    else
      calculate_easiness_factor
      calculate_interval
    end
    calculate_date
  end

  def interval
    @calculated_interval
  end

  def easiness_factor
    @calculated_ef
  end

  def next_repetition_date
    @repetition_date
  end

  private

  def calculate_interval
    if @prev_interval == 0
      @calculated_interval = 1
    elsif @prev_interval == 1
      @calculated_interval = 6
    else
      @calculated_interval = (@prev_interval * @prev_ef).to_i
    end
  end

  def calculate_easiness_factor
    @calculated_ef = @prev_ef + (0.1 - (5 - @quality_response) * (0.08 + (5 - @quality_response) * 0.02))
    if @calculated_ef < 1.3
      @calculated_ef = 1.3
    end
    @calculated_ef
  end

  def calculate_date
    @repetition_date = Date.today + @calculated_interval
  end
end