# frozen_string_literal: true

module Mobile
  class VoiceController < BaseController
    before_action :authenticate_user!
    skip_after_action :verify_authorized

    # GET /mobile/voice
    # Main voice interface screen
    def index
      @session = current_session
      @recent_recordings = VoiceRecording
        .where.not(metadata_extracted_at: nil)
        .order(updated_at: :desc)
        .limit(5)
    end

    # POST /mobile/voice/process
    # Process voice input from the user
    def process_input
      @session = current_session
      service = VoiceConversationService.new(@session)

      # Handle audio file upload or text input
      user_input = if params[:audio].present?
        save_audio_file(params[:audio])
      else
        params[:text]
      end

      @response = service.process(user_input)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: response_json }
      end
    end

    # POST /mobile/voice/start_recording
    # Start working on a specific voice recording
    def start_recording
      @session = current_session
      recording = VoiceRecording.find(params[:recording_id])
      @session.start_recording!(recording)

      redirect_to mobile_voice_path
    end

    # POST /mobile/voice/random_recording
    # Get a random recording that needs work
    def random_recording
      @session = current_session

      # Find recordings with unconfirmed entries
      recording = VoiceRecording
        .joins(:dictionary_entries)
        .where(dictionary_entries: { accuracy_status: :unconfirmed })
        .where.not(metadata_extracted_at: nil)
        .order("RANDOM()")
        .first

      if recording
        @session.start_recording!(recording)
        redirect_to mobile_voice_path
      else
        redirect_to mobile_voice_path, alert: "No recordings need review right now"
      end
    end

    # GET /mobile/voice/play_segment/:entry_id
    # Play an audio segment and speak the transcription
    def play_segment
      @entry = DictionaryEntry.find(params[:entry_id])
      @abair = AbairAdapter.new(dialect: :ulster, gender: :female)

      respond_to do |format|
        format.turbo_stream
        format.json do
          render json: {
            entry_id: @entry.id,
            audio_url: url_for(@entry.media),
            transcription: @entry.word_or_phrase,
            translation: @entry.translation,
            tts_audio: @abair.synthesize(@entry.word_or_phrase)
          }
        end
      end
    end

    # POST /mobile/voice/confirm_entry/:entry_id
    # Mark an entry as confirmed
    def confirm_entry
      @entry = DictionaryEntry.find(params[:entry_id])
      @entry.update!(accuracy_status: :confirmed)

      current_session.advance_to_next_entry!

      respond_to do |format|
        format.turbo_stream { redirect_to mobile_voice_path }
        format.json { render json: { status: "confirmed", next_entry_id: current_session.current_entry&.id } }
      end
    end

    # POST /mobile/voice/reset
    # Reset the current session
    def reset
      current_session.reset!
      redirect_to mobile_voice_path
    end

    private

    def save_audio_file(uploaded_file)
      path = Rails.root.join("tmp", "voice_#{SecureRandom.hex(8)}.webm")
      File.binwrite(path, uploaded_file.read)
      path.to_s
    end

    def response_json
      {
        text: @response.text,
        audio_url: @response.audio_url,
        action: @response.action,
        data: @response.data,
        session_state: @session.state,
        current_entry_id: @session.current_entry&.id
      }
    end

    def authenticate_user!
      return if current_user

      respond_to do |format|
        format.html { redirect_to login_path, alert: "Please sign in to continue" }
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
      end
    end
  end
end
