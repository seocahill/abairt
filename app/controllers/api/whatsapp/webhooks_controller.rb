# frozen_string_literal: true

module Api
  module Whatsapp
    # Receives WhatsApp Cloud API webhooks.
    #
    # Meta expects a 200 quickly and retries anything else, so this verifies the
    # signature, hands the payload to a job and gets out of the way.
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_after_action :verify_authorized

      before_action :verify_signature, only: :create

      # Meta's one-off subscription handshake.
      def show
        if params["hub.mode"] == "subscribe" && params["hub.verify_token"] == verify_token
          render plain: params["hub.challenge"]
        else
          head :forbidden
        end
      end

      def create
        ProcessWhatsappMessageJob.perform_later(params.permit!.to_h.except("controller", "action"))
        head :ok
      end

      private

      def verify_signature
        signature = request.headers["X-Hub-Signature-256"].to_s
        expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", app_secret.to_s, request.raw_post)

        return if app_secret.present? &&
          ActiveSupport::SecurityUtils.secure_compare(signature, expected)

        Rails.logger.warn("Rejected WhatsApp webhook with an invalid signature")
        head :unauthorized
      end

      def app_secret
        credential(:app_secret, "WHATSAPP_APP_SECRET")
      end

      def verify_token
        credential(:verify_token, "WHATSAPP_VERIFY_TOKEN")
      end

      def credential(key, env_key)
        Rails.application.credentials.dig(:whatsapp, key) || ENV[env_key]
      end
    end
  end
end
