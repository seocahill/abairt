class WordListDictionaryEntriesController < ApplicationController
  before_action :set_word_list_dictionary_entry, only: %i[ show edit update destroy ]


  # POST /list_entries or /list_entries.json
  def create
    list = WordList.find(word_list_dictionary_entry_params[:word_list_id])
    entry = DictionaryEntry.find(word_list_dictionary_entry_params[:dictionary_entry_id])

    if word_list_dictionary_entry = WordListDictionaryEntry.find_by(
      word_list_id: list.id,
      dictionary_entry_id: entry.id)
      word_list_dictionary_entry.destroy
    else
      WordListDictionaryEntry.create(word_list_dictionary_entry_params)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("dictionary_entry_#{entry.id}", partial: "dictionary_entries/dictionary_entry",
        locals: { entry: entry, current_user: current_user, starred: list })
      end
      format.html { redirect_to :back }
    end
  end

  # # PATCH/PUT /list_entries/1 or /list_entries/1.json
  # def update
  #   respond_to do |format|
  #     if @word_list_dictionary_entry.update(word_list_dictionary_entry_params)
  #       format.html { redirect_to word_list_dictionary_entry_url(@word_list_dictionary_entry), notice: "List entry was successfully updated." }
  #       format.json { render :show, status: :ok, location: @word_list_dictionary_entry }
  #     else
  #       format.html { render :edit, status: :unprocessable_entity }
  #       format.json { render json: @word_list_dictionary_entry.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # DELETE /list_entries/1 or /list_entries/1.json
  def destroy
    @word_list_dictionary_entry.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to :back, notice: "List entry was successfully destroyed." }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_word_list_dictionary_entry
      @word_list_dictionary_entry = WordListDictionaryEntry.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def word_list_dictionary_entry_params
      params.require(:word_list_dictionary_entry).permit(:dictionary_entry_id, :word_list_id)
    end
end
