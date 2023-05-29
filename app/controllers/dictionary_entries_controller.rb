# frozen_string_literal: true

class DictionaryEntriesController < ApplicationController
  before_action :set_dictionary_entry, only: %i[show edit update update_all destroy]
  before_action :authorize, only: %i[new create edit destroy]

  # GET /dictionary_entries or /dictionary_entries.json
  def index
    records = DictionaryEntry
      .joins(:speaker)
      .where("users.role != ?", 0)
      .where
      .not("(dictionary_entries.word_or_phrase <> '') IS NOT TRUE")
      .order(:id, :desc)

    if params[:search].present?
      records = records.joins(:fts_dictionary_entries).where("fts_dictionary_entries match ?", params[:search]).distinct.order('rank')
    end

    if params[:tag].present?
      records = records.tagged_with(params[:tag])
    end

    if params["media"].present?
      records = records.has_recording
    end

    if current_user
      @new_dictionary_entry = current_user.dictionary_entries.build
    end

    @tags = DictionaryEntry.tag_counts_on(:tags).most_used(15)

    if current_user
      @starred = current_user.starred
      @lists = current_user.own_lists #.where(starred: false)
    end

    @pagy, @dictionary_entries = pagy(records, items: PAGE_SIZE)

    respond_to do |format|
      format.html
      format.csv { send_data records.to_csv, filename: "dictionary-#{Date.today}.csv" }
      format.json { render json: records }
    end
  end

  # GET /dictionary_entries/1 or /dictionary_entries/1.json
  def show
    if current_user
      @starred = current_user.starred
      @lists = current_user.own_lists #.where(starred: false)
    end
  end

  # GET /dictionary_entries/new
  def new
    @dictionary_entry = DictionaryEntry.new
  end

  # GET /dictionary_entries/1/edit
  def edit; end

  # POST /dictionary_entries or /dictionary_entries.json
  def create
    @dictionary_entry = current_user.dictionary_entries.build(dictionary_entry_params)

    respond_to do |format|
      if @dictionary_entry.save
        format.html { redirect_to @dictionary_entry }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(:dictionary_entries, partial: "dictionary_entry",
          locals: { entry: @dictionary_entry, current_user: current_user, starred: current_user.starred })
        end
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /dictionary_entries/1 or /dictionary_entries/1.json
  def update
    if @dictionary_entry.update dictionary_entry_params
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @dictionary_entry,
            partial: "dictionary_entry",
            locals: { entry: @dictionary_entry, current_user: current_user, starred: current_user.starred }
          )
        end
        format.html { redirect_to @dictionary_entry, notice: 'entry was successfully updated.' }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /dictionary_entries/1 or /dictionary_entries/1.json
  def destroy
    broadcast = @dictionary_entry.rangs.any?
    @dictionary_entry.destroy
    Turbo::StreamsChannel.broadcast_remove_to("rangs", target: @dictionary_entry) if broadcast

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@dictionary_entry) }
      format.html         { redirect_to dictionary_entries_url }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_dictionary_entry
    @dictionary_entry = DictionaryEntry.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :speaker_id, :tag_list)
  end
end
