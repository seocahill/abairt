# frozen_string_literal: true

class DictionaryEntriesController < ApplicationController
  before_action :set_dictionary_entry, only: %i[show edit update update_all destroy]

  # GET /dictionary_entries or /dictionary_entries.json
  def index
    records = DictionaryEntry.order(id: :desc)
    
    # Only filter out low/fair quality entries if "show all" is not checked
    unless params[:show_all] == "1"
      records = records.not_low.not_fair
    end

    if params[:search].present?
      records = records.joins(:fts_dictionary_entries).where("fts_dictionary_entries match ?", params[:search]).distinct.order('rank')
    end

    if params[:tag].present?
      records = records.tagged_with(params[:tag])
    end

    if params["media"].present?
      records = records.has_recording
    end

    # Get all tags with counts
    @tags = DictionaryEntry.tag_counts_on(:tags).order(taggings_count: :desc)

    if current_user
      @new_dictionary_entry = current_user.dictionary_entries.build(speaker: current_user)
      @speaker_names = User.where(role: [:speaker, :teacher]).pluck(:name)
      @practice_word_list = current_user.word_lists.find_or_create_by!(name: 'Practice')
    end

    @pagy, @dictionary_entries = pagy(records, items: 15)

    respond_to do |format|
      format.html
      format.csv { send_data records.to_csv, filename: "dictionary-#{Date.today}.csv" }
      format.json { render json: records }
    end
  end

  # GET /dictionary_entries/1 or /dictionary_entries/1.json
  def show
  end

  # GET /dictionary_entries/new
  def new
    @dictionary_entry = DictionaryEntry.new(owner: current_user, speaker: current_user)
    authorize @dictionary_entry
  end

  # GET /dictionary_entries/1/edit
  def edit
    authorize @dictionary_entry
  end

  # POST /dictionary_entries or /dictionary_entries.json
  def create
    @dictionary_entry = DictionaryEntry.new(dictionary_entry_params.merge(user_id: current_user.id, quality: current_user.quality))
    @dictionary_entry.speaker = entry_speaker if entry_speaker
    authorize @dictionary_entry

    respond_to do |format|
      if @dictionary_entry.save
        # auto_tag
        AutoTagEntryJob.perform_later(@dictionary_entry)

        format.html { redirect_to dictionary_entries_path, notice: 'Dictionary entry was successfully created.' }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /dictionary_entries/1 or /dictionary_entries/1.json
  def update
    authorize @dictionary_entry

    # purge media
    if params.dig(:dictionary_entry, :purge)
      @dictionary_entry.media.purge
    end

    if @dictionary_entry.update dictionary_entry_params.merge(translator_id: current_user.id)
      regenerate_media
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @dictionary_entry,
            partial: "dictionary_entry",
            locals: { entry: @dictionary_entry, current_user: current_user }
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
    authorize @dictionary_entry
    @dictionary_entry.destroy
    respond_to do |format|
      format.turbo_stream { redirect_to dictionary_entries_url }
      format.html         { redirect_to dictionary_entries_url }
    end
  end

  # POST /dictionary_entries/1/generate_audio
  def generate_audio
    @dictionary_entry = DictionaryEntry.find(params[:id])

    # Use the synthesize_text_to_speech_and_store method from the DictionaryEntry model
    @dictionary_entry.synthesize_text_to_speech_and_store

    respond_to do |format|
      format.html { redirect_to @dictionary_entry, notice: 'Audio was successfully generated.' }
      format.json { render json: { success: true, audio_url: url_for(@dictionary_entry.media) } }
    end
  rescue => e
    Rails.logger.error("Error generating audio: #{e.message}")
    respond_to do |format|
      format.html { redirect_to @dictionary_entry, alert: 'Failed to generate audio.' }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def entry_speaker
    User.where(name: dictionary_entry_params[:speaker_id]&.strip).first_or_create do |user|
      user.email = "#{SecureRandom.alphanumeric}@abairt.com"
      user.role = :speaker
      user.ability = :native
      user.password = SecureRandom.alphanumeric
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_dictionary_entry
    @dictionary_entry = DictionaryEntry.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :speaker_id, :tag_list, :quality, :region_start, :region_end, :region_id, :translator_id)
  end

  def regenerate_media
    return unless @dictionary_entry.saved_change_to_region_start? ||
                  @dictionary_entry.saved_change_to_region_end?

    @dictionary_entry.media.purge
    @dictionary_entry.create_audio_snippet
  end
end
