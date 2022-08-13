  # frozen_string_literal: true
module Comhras
  class DictionaryEntriesController < ApplicationController
    before_action :set_dictionary_entry, only: %i[show edit update update_all destroy]
    before_action :set_comhra, only: %i[new create]

    # GET /dictionary_entries/1 or /dictionary_entries/1.json
    def show; end

    # GET /dictionary_entries/new
    def new
      @dictionary_entry = @comhra.dictionary_entries.new
    end

    # GET /dictionary_entries/1/edit
    def edit; end

    # POST /dictionary_entries or /dictionary_entries.json
    def create
      if params[:dictionary_entry][:dictionary_entry_id].present?
          @dictionary_entry = DictionaryEntry.find(params[:dictionary_entry][:dictionary_entry_id])
          @dictionary_entry.assign_attributes(dictionary_entry_params)
      else
        @dictionary_entry = @comhra.dictionary_entries.new(dictionary_entry_params)
      end

      respond_to do |format|
        if @dictionary_entry.save
          @comhra.dictionary_entries << @dictionary_entry
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
      @entry = DictionaryEntry.find_by(comhra_id: params[:comhra_id], dictionary_entry_id: params[:id])
      @entry.destroy!
      respond_to do |format|
        format.turbo_stream
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_dictionary_entry
      @dictionary_entry = DictionaryEntry.find(params[:id])
    end

    def set_comhra
      @comhra = Comhra.find(params[:comhra_id])
    end

    # Only allow a list of trusted parameters through.
    def dictionary_entry_params
      params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :search, :comhra_id, :status, :tag_list, :region_start, :region_end, :region_id)
    end
  end
end