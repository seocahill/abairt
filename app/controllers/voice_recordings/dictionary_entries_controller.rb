class VoiceRecordings::DictionaryEntriesController < ApplicationController
  # POST /dictionary_entries or /dictionary_entries.json
  def create
    @dictionary_entry = DictionaryEntry.new(dictionary_entry_params.merge(user_id: current_user.id, quality: current_user.quality))
    authorize @dictionary_entry
    
    # just assign the first user as the speaker initially
    @dictionary_entry.speaker = @dictionary_entry.voice_recording.users.first
    @dictionary_entry.translator = current_user

    respond_to do |format|
      if @dictionary_entry.save
        @dictionary_entry.create_audio_snippet
        AutoTagEntryJob.perform_later(@dictionary_entry)
        format.html { redirect_to @dictionary_entry.voice_recording }
        format.json { render json: { id: @dictionary_entry.id, message: 'Dictionary entry created successfully' }, status: :created }
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(:transcriptions, partial: "voice_recordings/dictionary_entries/dictionary_entry",
          locals: { entry: @dictionary_entry })
        end
      else
        format.html { redirect_back fallback_location: root_path, status: :unprocessable_entity }
        format.json { render json: { errors: @dictionary_entry.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def index
    @recording = VoiceRecording.find(params[:voice_recording_id])
    authorize @recording

    @pagy, @entries = pagy(@recording.dictionary_entries.includes(:speaker, :owner).order(region_start: :asc), items: 3)
    
    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("entries-list",
            partial: "voice_recordings/dictionary_entries/entries_list",
            locals: { entries: @entries, current_user: current_user, pagy: @pagy }
          )
        ]
      end
    end
  end

  def update
    @dictionary_entry = DictionaryEntry.find(params[:id])
    authorize @dictionary_entry

    if @dictionary_entry.update dictionary_entry_params.merge(translator_id: current_user.id)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "dictionary_entry_#{@dictionary_entry.id}",
            partial: "voice_recordings/dictionary_entries/entry",
            locals: { entry: @dictionary_entry }
          )
        end
        format.html { redirect_to voice_recording_dictionary_entries_path(@dictionary_entry.voice_recording), notice: 'Entry was successfully updated.' }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private


  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :search, :voice_recording_id, :status, :tag_list, :region_start, :region_end, :region_id, :speaker_id, :quality, :translator_id, rang_ids: [])
  end
end
