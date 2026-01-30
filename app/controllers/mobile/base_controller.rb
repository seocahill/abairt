# frozen_string_literal: true

module Mobile
  class BaseController < ApplicationController
    layout "mobile"

    before_action :require_turbo_native_app, unless: -> { Rails.env.development? }

    private

    def require_turbo_native_app
      return if turbo_native_app?

      redirect_to root_path, alert: "This feature requires the mobile app"
    end

    # Find or create conversation session for current user
    def current_session
      @current_session ||= ConversationSession.find_or_create_by!(user: current_user) do |session|
        session.state = "idle"
      end
    end
    helper_method :current_session
  end
end
