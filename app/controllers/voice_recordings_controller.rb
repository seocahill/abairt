class VoiceRecordingsController < ApplicationController
  before_action :set_voice_recording, only: %i[ show edit update destroy add_region ]

  def index
    @new_voice_recording = VoiceRecording.new
    records = VoiceRecording.order(dictionary_entries_count: :desc)

    if params[:preview].present?
      @recording = VoiceRecording.find(params[:preview])
    end

    if params[:search].present?
      records = VoiceRecording
        .joins(:users)
        .where("title LIKE ?", "%#{params[:search]}%")
        .or(VoiceRecording.joins(:users).where("users.name LIKE ?", "%#{params[:search]}%"))
    end

    if params[:tag].present?
      records = records.tagged_with(params[:tag])
    end

    if params[:voice].present?
      value =  User.voices[params[:voice]]
      records = records.joins(:users).where("users.voice = ?", value)
    end

    if params[:dialect].present?
      value =  User.dialects[params[:dialect]]
      records = records.joins(:users).where("users.dialect = ?", value)
    end

    @pagy, @recordings = pagy(records.distinct, items: 10)
    @regions = set_regions if @voice_recording
    @tags = VoiceRecording.tag_counts_on(:tags).most_used(15)
  end

  def map
    authorize(VoiceRecording)
    @pins = VoiceRecording.all.map do |vr|
      next unless speaker = vr.dictionary_entries.joins(:speaker).where("users.lat_lang is not null").first&.speaker

      speaker.slice(:id, :name, :lat_lang).tap do |c|
        c[:recording_id] = vr.id
        c[:recording_title] = vr.title
      end
    end.compact
  end

  def show
    @recording = VoiceRecording.find(params[:id])
    @regions = set_regions
    if current_user
      @last_speaker_name = @recording.dictionary_entries.last&.speaker&.name
      @new_dictionary_entry = @recording.dictionary_entries.build
      @speaker_names = User.where(role: [:speaker, :teacher]).pluck(:name)
    end
    @pagy, @entries = pagy(@recording.dictionary_entries.where.not(id: nil).reorder(:region_start), items: PAGE_SIZE)
  end

  def preview
    @recording = VoiceRecording.find(params[:id])
    authorize @recording
    @regions = set_regions
    render partial: 'waveform', locals: { recording:  @recording, regions: @regions }
  end

  # GET /voice_recordings/new
  def new
    @voice_recording = VoiceRecording.new(owner: current_user)
    authorize @voice_recording
  end

  # GET /voice_recordings/1/edit
  def edit
    authorize @voice_recording
  end

  # POST /voice_recordings or /voice_recordings.json
  def create
    @voice_recording = VoiceRecording.new(voice_recording_params.merge(user_id: current_user.id))
    authorize @voice_recording

    respond_to do |format|
      if @voice_recording.save
        format.html { redirect_to voice_recording_url(@voice_recording), notice: "Voice recording was successfully created." }
        format.json { render :show, status: :created, location: @voice_recording }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @voice_recording.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /voice_recordings/1 or /voice_recordings/1.json
  def update
    authorize @voice_recording
    respond_to do |format|
      if @voice_recording.update(voice_recording_params)
        if @voice_recording.transcription.present? && @voice_recording.dictionary_entries.empty?
          ImportTranscriptionJob.perform_later(@voice_recording, params[:speaker_id])
        end
        format.html { redirect_to voice_recording_url(@voice_recording), notice: "Voice recording was successfully updated." }
        format.json { render :show, status: :ok, location: @voice_recording }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @voice_recording.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /voice_recordings/1 or /voice_recordings/1.json
  def destroy
    authorize @voice_recording
    @voice_recording.destroy

    respond_to do |format|
      format.html { redirect_to voice_recordings_url, notice: "Voice recording was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def add_region
    previous_entry = @voice_recording.dictionary_entries.where("region_end IS NOT NULL").order("region_end DESC").first
    entry = previous_entry ? @voice_recording.dictionary_entries.where("dictionary_entries.id > ?", previous_entry.id).first : @voice_recording.dictionary_entries.first

    authorize(entry)

    entry.region_start = previous_entry&.region_end.to_d + 0.01
    entry.region_end = params[:current_position]

    respond_to do |format|
      if entry.save
        entry.create_audio_snippet
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(:transcriptions, partial: "voice_recordings/dictionary_entries/dictionary_entry",
          locals: { entry: entry })
        end
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_voice_recording
      @voice_recording = VoiceRecording.find(params[:id])
    end

    def set_regions
      @recording.dictionary_entries.map { |e| e.slice(:region_id, :region_start, :region_end, :word_or_phrase, :translation, :id)}.to_json
    end

    # Only allow a list of trusted parameters through.
    def voice_recording_params
      params.require(:voice_recording).permit(:title, :description, :transcription, :transcription_en, :media, :tag_list, user_ids: [])
    end

end
