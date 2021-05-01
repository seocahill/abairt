# frozen_string_literal: true

class DictionaryEntriesController < ApplicationController
  before_action :set_dictionary_entry, only: %i[show edit update destroy update_all]
  before_action :set_rang, only: %i[new create]

  # GET /dictionary_entries or /dictionary_entries.json
  def index
    records = DictionaryEntry.where.not("(dictionary_entries.word_or_phrase <> '') IS NOT TRUE")

    if params[:search].present?
      records = records.joins(:searches).where("search.translation match ?", params[:search]).distinct
    end

    records.order('id DESC')

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
    @dictionary_entry = @rang.dictionary_entries.new(dictionary_entry_params)

    respond_to do |format|
      if @dictionary_entry.save
        @rang.dictionary_entries << @dictionary_entry
        format.turbo_stream
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /dictionary_entries/1 or /dictionary_entries/1.json
  def update
    @dictionary_entry.update(dictionary_entry_params)
    respond_to do |format|
      format.turbo_stream
    end
  end

  def update_all
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
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :search, :rang_id, :status)
  end
end
