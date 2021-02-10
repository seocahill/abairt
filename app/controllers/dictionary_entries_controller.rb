class DictionaryEntriesController < ApplicationController
  before_action :set_dictionary_entry, only: %i[ show edit update destroy ]

  # GET /dictionary_entries or /dictionary_entries.json
  def index
    @dictionary_entries = DictionaryEntry.all
  end

  # GET /dictionary_entries/1 or /dictionary_entries/1.json
  def show
  end

  # GET /dictionary_entries/new
  def new
    @dictionary_entry = DictionaryEntry.new
  end

  # GET /dictionary_entries/1/edit
  def edit
  end

  # POST /dictionary_entries or /dictionary_entries.json
  def create
    @dictionary_entry = DictionaryEntry.new(dictionary_entry_params)

    respond_to do |format|
      if @dictionary_entry.save
        format.html { redirect_to @dictionary_entry, notice: "Dictionary entry was successfully created." }
        format.json { render :show, status: :created, location: @dictionary_entry }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @dictionary_entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /dictionary_entries/1 or /dictionary_entries/1.json
  def update
    respond_to do |format|
      if @dictionary_entry.update(dictionary_entry_params)
        format.html { redirect_to @dictionary_entry, notice: "Dictionary entry was successfully updated." }
        format.json { render :show, status: :ok, location: @dictionary_entry }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @dictionary_entry.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /dictionary_entries/1 or /dictionary_entries/1.json
  def destroy
    @dictionary_entry.destroy
    respond_to do |format|
      format.html { redirect_to dictionary_entries_url, notice: "Dictionary entry was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dictionary_entry
      @dictionary_entry = DictionaryEntry.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def dictionary_entry_params
      params.require(:dictionary_entry).permit(:word_or_phrase, :translation)
    end
end
