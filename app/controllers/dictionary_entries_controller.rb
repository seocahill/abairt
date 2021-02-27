# frozen_string_literal: true

class DictionaryEntriesController < ApplicationController
  before_action :set_dictionary_entry, only: %i[show edit update destroy]
  before_action :set_rang, only: %i[new create]

  # GET /dictionary_entries or /dictionary_entries.json
  def index
    records = if params[:search].present?
                DictionaryEntry.search_translation(params[:search])
              else
                DictionaryEntry.order('id DESC')
              end

    @pagy, @dictionary_entries = pagy(records)

    respond_to do |format|
      format.html
      format.csv { send_data @dictionary_entries.to_csv, filename: "dictionary-#{Date.today}.csv" }
    end
  end

  # GET /dictionary_entries/1 or /dictionary_entries/1.json
  def show; end

  # GET /dictionary_entries/new
  def new
    @dictionary_entry = @rang.dictionary_entries.new
  end

  # GET /dictionary_entries/1/edit
  def edit; end

  # POST /dictionary_entries or /dictionary_entries.json
  def create
    @dictionary_entry = @rang.dictionary_entries.create!(dictionary_entry_params)

    respond_to do |format|
      format.turbo_stream
      # format.html { redirect_to @rang, notice: 'Dictionary entry was successfully created.' }
    end
  end

  # PATCH/PUT /dictionary_entries/1 or /dictionary_entries/1.json
  def update
    @dictionary_entry.update(dictionary_entry_params)
    respond_to do |format|
      format.turbo_stream
    end
  end

  # DELETE /dictionary_entries/1 or /dictionary_entries/1.json
  def destroy
    @dictionary_entry.destroy
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_dictionary_entry
    @dictionary_entry = DictionaryEntry.find(params[:id])
  end

  def set_rang
    @rang = Rang.find(params[:rang_id])
  end

  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :search, :rang_id)
  end
end
