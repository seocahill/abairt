class CeistController < ApplicationController
  before_action :authorize

  def new
    DictionaryEntry
      .joins(:rang)
      .where( rangs: { user_id: current_user.id })
      .where("date_trunc('day', recall_date) = date_trunc('day', current_date) OR recall_date IS NULL" )
      .take
  end

  def create
    next_recall_date = Supermemo.new(easiness_factor: 2.5, interval: 0, repetitions: 0).recall(params[:quality_of_recall])
    DictionaryEntry.find(param[:entry_id]).update(recall_date: next_recall_date)
  end
end
