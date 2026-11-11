# frozen_string_literal: true

module Api
  # Recordings with their transcript, line by line with times, for apps that
  # play them to learners, such as the Mayo Irish course and the Android
  # listening app. Needs an API token: the website is open to read, but the API
  # is for apps that identify themselves, so one can be limited or revoked.
  class VoiceRecordingsController < BaseController
    DEFAULT_LIMIT = 10
    MAX_LIMIT = 50

    # A night of radio on short recordings is near a hundred requests an hour.
    rate_limit to: 300, within: 1.hour, by: -> { current_api_user&.id || request.remote_ip }

    # GET /api/voice_recordings
    #
    # Recordings to play, newest first, or in random order with `shuffle=true`
    # (the radio). `exclude_ids[]` leaves out ones already heard, so a radio
    # does not repeat itself. Transcripts come from the show action.
    def index
      recordings = VoiceRecording.listenable.with_attached_audio_track.with_attached_media
      recordings = recordings.where.not(id: Array(params[:exclude_ids]).map(&:to_i)) if params[:exclude_ids].present?
      recordings = shuffle? ? recordings.reorder(Arel.sql("RANDOM()")) : recordings.reorder(id: :desc)

      render json: {recordings: Api::RecordingSummarySerializer.new(recordings.limit(limit)).serializable_hash}
    end

    # GET /api/voice_recordings/:id
    #
    # Only checked lines, unless `unchecked=true`: the machine's transcript of
    # most recordings has not been checked yet, and each line says which it is.
    def show
      recording = VoiceRecording.find(params[:id])
      return render(json: {error: "Not found"}, status: :not_found) unless recording.listening_audio

      lines = recording.transcript_lines(include_unchecked: flag(:unchecked))
      render json: Api::RecordingTranscriptSerializer.new(recording, params: {lines: lines}).serializable_hash
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Not found"}, status: :not_found
    end

    private

    def shuffle? = flag(:shuffle)

    def limit = params.fetch(:limit, DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)

    def flag(name) = ActiveModel::Type::Boolean.new.cast(params[name]) || false
  end
end
