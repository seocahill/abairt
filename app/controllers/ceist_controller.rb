class CeistController < ApplicationController
  before_action :authorize

  def new
    @dictionary_entry = DictionaryEntry
      .joins(:rangs)
      .where(rangs: { user_id: current_user.id })
      .where(committed_to_memory: false)
      .where("date_trunc('day', recall_date) = date_trunc('day', current_date) OR recall_date IS NULL")
      .take
  end

  def create
    dictionary_entry = DictionaryEntry.find(params[:entry_id])
    if params[:quality_of_recall].to_i == 5 && @dictionary_entry.recall_date.nil?
      dictionary_entry.update(committed_to_memory: true)
    else
      super_memo = SuperMemoService.new(params[:quality_of_recall].to_i, dictionary_entry.previous_inteval, dictionary_entry.previous_easiness_factor)
      dictionary_entry.update(
        recall_date: super_memo.next_repetition_date,
        previous_inteval: super_memo.interval,
        previous_easiness_factor: super_memo.easiness_factor,
      )
    end
    redirect_to ceist_path
  end

  private

  def authorize
    current_user.present?
  end
end
