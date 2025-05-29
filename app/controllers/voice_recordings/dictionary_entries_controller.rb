class VoiceRecordings::DictionaryEntriesController < ApplicationController
  # POST /dictionary_entries or /dictionary_entries.json
  def create
    @dictionary_entry = DictionaryEntry.new(dictionary_entry_params.merge(user_id: current_user.id, quality: current_user.quality))
    authorize @dictionary_entry

    # datalist sends name over the wire, need id. Also might not exist yet.
    speaker = User.where(name: dictionary_entry_params[:speaker_id]).first_or_create do |user|
      user.email = "#{dictionary_entry_params[:speaker_id]}@abairt.com"
      user.role = :speaker
      user.ability = :native
      user.password = SecureRandom.alphanumeric
    end

    @dictionary_entry.speaker = speaker

    respond_to do |format|
      if @dictionary_entry.save
        @dictionary_entry.create_audio_snippet
        AutoTagEntryJob.perform_later(@dictionary_entry)
        format.html { redirect_to @dictionary_entry.voice_recording }
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(:transcriptions, partial: "voice_recordings/dictionary_entries/dictionary_entry",
          locals: { entry: @dictionary_entry })
        end
      else
        format.html { redirect_back fallback_location: root_path, status: :unprocessable_entity }
      end
    end
  end

  def index
    @recording = VoiceRecording.find(params[:voice_recording_id])
    authorize @recording

    @pagy, @entries = pagy(@recording.dictionary_entries.includes(:speaker, :owner), items: 10)
  end

  private


  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :search, :voice_recording_id, :status, :tag_list, :region_start, :region_end, :region_id, :speaker_id, :quality, rang_ids: [])
  end
end
