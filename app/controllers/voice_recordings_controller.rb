class VoiceRecordingsController < ApplicationController
  before_action :set_voice_recording, only: %i[show edit update destroy add_region import_status retranscribe]
  PAGE_SIZE = 15 # Define the constant at the top of the controller

  def index
    @new_voice_recording = VoiceRecording.new
    records = VoiceRecording.all

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
      value = User.voices[params[:voice]]
      records = records.joins(:users).where("users.voice = ?", value)
    end

    if params[:dialect].present?
      value = User.dialects[params[:dialect]]
      records = records.joins(:users).where("users.dialect = ?", value)
    end

    # Apply sorting
    records = case params[:order]
    when "oldest"
      records.order(created_at: :asc)
    when "best"
      records.order(dictionary_entries_count: :desc)
    else # "newest" or default
      records.order(created_at: :desc)
    end

    @total_count = records.distinct.count
    @pagy, @recordings = pagy(records.distinct, items: PAGE_SIZE)
    # @regions = set_regions if @voice_recording
    @tags = VoiceRecording.tag_counts_on(:tags).most_used(15)

    # Add map pins data - single query instead of N+1
    @pins = DictionaryEntry
      .joins(:speaker, :voice_recording)
      .where.not(users: {lat_lang: nil})
      .group("voice_recordings.id")
      .pluck("users.id", "users.name", "users.lat_lang", "voice_recordings.id", "voice_recordings.title")
      .map do |user_id, name, lat_lang, recording_id, recording_title|
        {id: user_id, name: name, lat_lang: lat_lang, recording_id: recording_id, recording_title: recording_title}
      end

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append(
            "recordings-container",
            partial: "recording",
            collection: @recordings
          ),
          turbo_stream.replace(
            "pagination",
            partial: "shared/pagination",
            locals: {pagy: @pagy, infinite_scroll: true}
          )
        ]
      end
    end
  end

  def show
    @recording = VoiceRecording.find(params[:id])
    @regions = set_regions
    if current_user
      @last_speaker_name = @recording.dictionary_entries.last&.speaker&.name
      @new_dictionary_entry = @recording.dictionary_entries.build
      @speaker_names = User.where(role: [:speaker, :teacher]).pluck(:name)
    end

    # Improve pagination query to be more efficient
    @pagy, @entries = pagy(
      @recording.dictionary_entries
        .includes(:speaker, :versions, media_attachment: :blob)
        .where.not(id: nil)
        .reorder(:region_start),
      items: PAGE_SIZE
    )

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("entries-container",
            partial: "voice_recordings/dictionary_entries/entry",
            collection: @entries),
          turbo_stream.replace("pagination",
            partial: "shared/pagination",
            locals: {pagy: @pagy})
        ]
      end
    end
  end

  def import_status
    authorize @voice_recording
    render json: {
      status: @voice_recording.import_status,
      media_attached: @voice_recording.media.attached?
    }
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
    @voice_recording = VoiceRecording.new(voice_recording_params.except(:trim_start, :trim_end, :should_trim, :use_fotheidil_api).merge(user_id: current_user.id))
    authorize @voice_recording

    respond_to do |format|
      if @voice_recording.save
        # Process with Fotheidil operation (handles upload or existing video_id)
        ProcessFotheidilVideoJob.perform_later(@voice_recording.id, voice_recording_params[:fotheidil_video_id])

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

  def retranscribe
    authorize @voice_recording

    duplicate = @voice_recording.dup
    duplicate.assign_attributes(
      description: "Retranscription of #{@voice_recording.title} (original: /voice_recordings/#{@voice_recording.id})",
      diarization_status: nil,
      import_status: nil,
      diarization_data: nil,
      dictionary_entries_count: 0
    )
    duplicate.media.attach(@voice_recording.media.blob)

    if duplicate.save
      ProcessFotheidilVideoJob.perform_later(duplicate.id, @voice_recording.fotheidil_video_id)
      redirect_to voice_recording_url(duplicate), notice: "Retranscription started. This may take several minutes."
    else
      redirect_to voice_recording_url(@voice_recording), alert: "Failed to create retranscription: #{duplicate.errors.full_messages.join(", ")}"
    end
  end

  def add_region
    entry = @voice_recording.dictionary_entries.new(voice_recording_params.merge(user_id: current_user.id))

    authorize(entry)

    # add a small amount of time to the region start to avoid overlap
    entry.region_start += 0.01
    respond_to do |format|
      if entry.save
        entry.create_audio_snippet
        format.html { redirect_to voice_recording_url(@voice_recording), notice: "New segment added." }
      else
        format.html { redirect_to voice_recording_url(@voice_recording), alert: "Failed to add new segment #{entry.errors.full_messages.join(", ")}." }
      end
    end
  end

  def subtitles
    @recording = VoiceRecording.find(params[:id])
    authorize @recording, :show?
    @entries = @recording.dictionary_entries.order(:region_start)
    @lang = params[:lang] || "ga"

    Rails.logger.debug { "Generating subtitles for recording #{@recording.id} in language #{@lang}" }
    Rails.logger.debug { "Found #{@entries.count} entries" }
    Rails.logger.debug { "First entry: #{@entries.first.attributes}" } if @entries.any?

    response.headers["Content-Type"] = "text/vtt; charset=utf-8"
    response.headers["Content-Disposition"] = "inline; filename=#{@recording.title}_#{@lang}.vtt"
    response.headers["Access-Control-Allow-Origin"] = "*"

    render layout: false
  end

  def regions
    @recording = VoiceRecording.find(params[:id])
    authorize @recording, :show?

    regions = @recording.dictionary_entries.map { |e|
      e.slice(:region_id, :region_start, :region_end, :word_or_phrase, :translation, :id)
    }

    Rails.logger.debug { "Sending regions: #{regions.inspect}" }
    render json: regions
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_voice_recording
    @voice_recording = VoiceRecording.find(params[:id])
  end

  def set_regions
    @recording.dictionary_entries.map { |e|
      e.slice(:region_id, :region_start, :region_end, :word_or_phrase, :translation, :id)
    }
  end

  # Only allow a list of trusted parameters through.
  def voice_recording_params
    params.require(:voice_recording).permit(:title, :description, :transcription, :transcription_en, :media, :tag_list, :region_id, :region_start, :region_end, :use_fotheidil_api, :fotheidil_video_id, user_ids: [])
  end
end
