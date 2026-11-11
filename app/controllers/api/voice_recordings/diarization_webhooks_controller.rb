module Api
  module VoiceRecordings
    class DiarizationWebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_after_action :verify_authorized

      before_action :verify_secret

      def create
        voice_recording = VoiceRecording.find(params[:voice_recording_id])
        service = DiarizationService.new(voice_recording)

        if service.handle_webhook(params.permit!.to_h)
          head :ok
        else
          head :unprocessable_entity
        end
      end

      private

      # The secret rides in the webhook URL we hand to the diarization provider
      # (see DiarizationService). Until DIARIZATION_WEBHOOK_SECRET is set the
      # check is skipped, so existing jobs keep working; once set, a missing or
      # wrong token is rejected.
      def verify_secret
        return if DiarizationService.webhook_secret.blank?

        given = params[:token].to_s
        return if ActiveSupport::SecurityUtils.secure_compare(given, DiarizationService.webhook_secret)

        Rails.logger.warn("Rejected diarization webhook with an invalid token")
        head :unauthorized
      end
    end
  end
end
