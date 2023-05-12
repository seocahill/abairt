class VoiceRecordings::DictionaryEntriesController < ApplicationController
  before_action :authorize
  # POST /dictionary_entries or /dictionary_entries.json
  def create
    @dictionary_entry = DictionaryEntry.new(dictionary_entry_params)

    respond_to do |format|
      if @dictionary_entry.save
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(:transcriptions, partial: "voice_recordings/dictionary_entries/dictionary_entry",
          locals: { entry: @dictionary_entry })
        end
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :search, :voice_recording_id, :status, :tag_list, :region_start, :region_end, :region_id, :speaker_id, rang_ids: [])
  end
end
