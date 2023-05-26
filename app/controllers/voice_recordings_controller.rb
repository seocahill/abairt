class VoiceRecordingsController < ApplicationController
  before_action :set_voice_recording, only: %i[ show edit update destroy ]
  before_action :authorize, except: %i[index show preview]

  def index
    @new_voice_recording = VoiceRecording.new
    records = VoiceRecording.order(:id, :desc)

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

    @pagy, @recordings = pagy(records.distinct, items: PAGE_SIZE)
    @regions = set_regions if @voice_recording
    @tags = VoiceRecording.tag_counts_on(:tags).most_used(15)
  end

  def show
    @recording = VoiceRecording.find(params[:id])
    @regions = set_regions
    @new_dictionary_entry = @recording.dictionary_entries.build
    @pagy, @entries = pagy(@recording.dictionary_entries.where.not(id: nil), items: PAGE_SIZE)
  end

  def preview
    @recording = VoiceRecording.find(params[:id])
    @regions = set_regions
    render partial: 'waveform', locals: { recording:  @recording, regions: @regions }
  end

  # GET /voice_recordings/new
  def new
    @voice_recording = VoiceRecording.new
  end

  # GET /voice_recordings/1/edit
  def edit
  end

  # POST /voice_recordings or /voice_recordings.json
  def create
    @voice_recording = VoiceRecording.new(voice_recording_params)

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
    respond_to do |format|
      if @voice_recording.update(voice_recording_params)
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
    @voice_recording.destroy

    respond_to do |format|
      format.html { redirect_to voice_recordings_url, notice: "Voice recording was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_voice_recording
      @voice_recording = VoiceRecording.find(params[:id])
    end

    def set_regions
      @recording.dictionary_entries.map { |e| e.slice(:region_id, :region_start, :region_end, :word_or_phrase, :translation)}.to_json
    end

    # Only allow a list of trusted parameters through.
    def voice_recording_params
      params.require(:voice_recording).permit(:title, :description, :media, :tag_list, user_ids: [])
    end

    def authorize
      return if current_user

      redirect_back(fallback_location: root_path, alert: "Caithfidh tú a bheith sínithe isteach!")
    end
end
