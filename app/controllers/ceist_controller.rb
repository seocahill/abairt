class CeistController < ApplicationController
  before_action :authorize

  def new
    @dictionary_entry = DictionaryEntry
      .joins(:rangs)
      .where( rangs: { user_id: current_user.id })
      .where("date_trunc('day', recall_date) = date_trunc('day', current_date) OR recall_date IS NULL" )
      .take
  end

  def create
    # binding.pry
    next_recall_date = SuperMemoService.new(easiness_factor: 2.5, interval: 0, repetitions: 0).recall(params[:quality_of_recall].to_i)
    DictionaryEntry.find(params[:entry_id]).update(recall_date: next_recall_date)
    redirect_to ceist_path
  end

  private

  def authorize
    current_user.present?
  end
end
