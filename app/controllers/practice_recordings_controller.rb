class PracticeRecordingsController < ApplicationController

  def create
    authorize :practice_recording, :create?
    entry = DictionaryEntry.find(params[:dictionary_entry_id])
    word_list = current_user.word_lists.find_or_create_by!(name: 'Practice')
    list_entry = WordListDictionaryEntry.find_or_create_by!(word_list: word_list, dictionary_entry: entry)

    if params[:media].present?
      list_entry.recordings.attach(params[:media])
    end

    # Set up the practice word list for the partial
    @practice_word_list = word_list

    respond_to do |format|
      format.html { redirect_to dictionary_entries_path, notice: 'Practice recording saved.' }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("dictionary_entry_#{entry.id}", partial: "dictionary_entries/dictionary_entry", locals: { entry: entry, current_user: current_user, practice_word_list: @practice_word_list }) }
    end
  end
end 