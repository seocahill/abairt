class VoiceRecordingsController < ApplicationController
  before_action :set_voice_recording, only: %i[ show edit update destroy ]
  before_action :authorize, except: %i[index show]

  def index
    @pagy, @files = pagy(ActiveStorage::Attachment.where(record_type: "Rang"), items: 12)
    @rang = Rang.with_attached_media.find(56)
    @regions = @rang.dictionary_entries.map { |e| e.slice(:region_id, :region_start, :region_end, :word_or_phrase)}.to_json
    @tags = ActsAsTaggableOn::Tag.most_used(15)
  end

  def show
    records = Rang.where(grupa_id: params[:id])
    @pagy, @rangs = pagy(records)
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

    # Only allow a list of trusted parameters through.
    def voice_recording_params
      params.require(:voice_recording).permit(:title, :description)
    end
end
