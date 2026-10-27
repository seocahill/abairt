# frozen_string_literal: true

module Api
  # A whole recording with its confirmed transcript, line by line with times,
  # for apps that play it to learners, such as the Mayo Irish course.
  class VoiceRecordingsController < BaseController
    rate_limit to: 100, within: 1.hour, by: -> { current_api_user&.id || request.remote_ip }

    # GET /api/voice_recordings/:id
    def show
      recording = VoiceRecording.find(params[:id])
      return render(json: {error: "Not found"}, status: :not_found) unless recording.listening_audio

      render json: Api::RecordingTranscriptSerializer.new(recording, params: {lines: recording.transcript_lines}).serializable_hash
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Not found"}, status: :not_found
    end
  end
end
