module Api
  module VoiceRecordings
    class DiarizationWebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_after_action :verify_authorized

      def create
        voice_recording = VoiceRecording.find(params[:voice_recording_id])
        service = DiarizationService.new(voice_recording)

        if service.handle_webhook(params.permit!.to_h)
          head :ok
        else
          head :unprocessable_entity
        end
      end
    end
  end
end
