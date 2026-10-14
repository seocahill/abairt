# frozen_string_literal: true

module Api
  module Telegram
    # Receives Telegram Bot API webhooks.
    #
    # Telegram retries anything that is not a 200, so this checks the secret,
    # hands the payload to a job and gets out of the way.
    #
    # Simpler than its WhatsApp counterpart in two ways: the secret is a string
    # Telegram echoes back rather than an HMAC over the body, and there is no
    # subscription handshake — setWebhook is a one-off call at setup.
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token
      skip_after_action :verify_authorized

      before_action :verify_secret

      def create
        ProcessTelegramMessageJob.perform_later(params.permit!.to_h.except("controller", "action"))
        head :ok
      end

      private

      # Without a configured secret anyone who learns the URL can post to it, so
      # an absent secret rejects rather than waves through.
      def verify_secret
        given = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s

        return if secret.present? && ActiveSupport::SecurityUtils.secure_compare(given, secret)

        Rails.logger.warn("Rejected Telegram webhook with an invalid secret token")
        head :unauthorized
      end

      def secret
        Rails.application.credentials.dig(:telegram, :webhook_secret) || ENV["TELEGRAM_WEBHOOK_SECRET"]
      end
    end
  end
end
