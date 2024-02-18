# frozen_string_literal: true

class DictionaryEntriesController < ApplicationController
  before_action :set_dictionary_entry, only: %i[show edit update update_all destroy]

  # GET /dictionary_entries or /dictionary_entries.json
  def index
    records = DictionaryEntry
      .not_low
      .order(:id, :desc)

    if params[:search].present?
      records = records.joins(:fts_dictionary_entries).where("fts_dictionary_entries match ?", params[:search]).distinct.order('rank')
    end

    if params[:tag].present?
      records = records.tagged_with(params[:tag])
    end

    if params["media"].present?
      records = records.has_recording
    end

    if current_user
      @new_dictionary_entry = current_user.dictionary_entries.build(speaker: current_user)
      @speaker_names = User.where(role: [:speaker, :teacher]).pluck(:name)
    end

    @tags = DictionaryEntry.tag_counts_on(:tags).most_used(15)

    if current_user
      @starred = current_user.starred
      @lists = current_user.own_lists #.where(starred: false)
    end

    @pagy, @dictionary_entries = pagy(records, items: PAGE_SIZE)

    respond_to do |format|
      format.html
      format.csv { send_data records.to_csv, filename: "dictionary-#{Date.today}.csv" }
      format.json { render json: records }
    end
  end

  # GET /dictionary_entries/1 or /dictionary_entries/1.json
  def show
    if current_user
      @starred = current_user.starred
      @lists = current_user.own_lists #.where(starred: false)
    end
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
        if ENV['AUTO_TAG_ENABLED']
          AutoTagEntryJob.perform_later(@dictionary_entry)
        end

        format.html { redirect_to @dictionary_entry }
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend(:dictionary_entries, partial: "dictionary_entry",
          locals: { entry: @dictionary_entry, current_user: current_user, starred: current_user.starred })
        end
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

    # datalist sends name over the wire, need id. Also might not exist yet.
    @dictionary_entry.speaker = entry_speaker if entry_speaker
    @dictionary_entry.quality = current_user.quality

    if @dictionary_entry.update dictionary_entry_params
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @dictionary_entry,
            partial: partial,
            locals: { entry: @dictionary_entry, current_user: current_user, starred: current_user.starred }
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
    broadcast = @dictionary_entry.rangs.any?
    @dictionary_entry.destroy
    Turbo::StreamsChannel.broadcast_remove_to("rangs", target: @dictionary_entry) if broadcast

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@dictionary_entry) }
      format.html         { redirect_to dictionary_entries_url }
    end
  end

  def add_region
    entry = DictionaryEntry.find(params[:id])
    previous_entry = DictionaryEntry.where("region_end IS NOT NULL").order("region_end DESC").first

    entry.region_start = @previous_entry.region_end ? @previous_entry.region_end + 0.01 : 0.0
    entry.region_end = params[:current_position]

    respond_to do |format|
      if entry.save
        entry.create_audio_snippet
        format.html { redirect_to entry.voice_recording }
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(:transcriptions, partial: "voice_recordings/dictionary_entries/dictionary_entry",
          locals: { entry: entry })
        end
      else
        format.html { redirect_back fallback_location: root_path, status: :unprocessable_entity }
      end
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

  def partial
    # hack but it'll do for now
    @dictionary_entry.voice_recording_id ? "voice_recordings/dictionary_entries/dictionary_entry" : "dictionary_entry"
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_dictionary_entry
    @dictionary_entry = DictionaryEntry.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def dictionary_entry_params
    params.require(:dictionary_entry).permit(:word_or_phrase, :translation, :notes, :media, :speaker_id, :tag_list, :quality)
  end
end
