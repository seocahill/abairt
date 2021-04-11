class CeistController < ApplicationController
  before_action :authorize

  # GET /dictionary_entries or /dictionary_entries.json
  def index
    records = DictionaryEntry
      .joins(:rangs)
      .where(rangs: { user_id: current_user.daltaí.pluck(:id) + [current_user.id] })
      .not_normal

    @pagy, @ceisteanna = pagy(records)

    respond_to do |format|
      format.html
    end
  end

  def new
    @dictionary_entry = DictionaryEntry
      .joins(:rangs)
      .where(rangs: { user_id: current_user.id })
      .where(committed_to_memory: false)
      .where("translation is not null")
      .where("date_trunc('day', recall_date) = date_trunc('day', current_date) OR recall_date IS NULL")
      .sample
  end

  def create
    dictionary_entry = DictionaryEntry.find(params[:entry_id])
    if params[:quality_of_recall].nil?
      dictionary_entry.update!(committed_to_memory: true)
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

  def update
    @dictionary_entry = DictionaryEntry.find(params[:id])
    @dictionary_entry.ceist? ? @dictionary_entry.normal! : @dictionary_entry.ceist!
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def authorize
    return if current_user

    redirect_to root_path
  end
end
