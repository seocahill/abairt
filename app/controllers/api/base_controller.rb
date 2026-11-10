# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include Rails.application.routes.url_helpers

    before_action :authenticate_api_token!

    private

    def authenticate_api_token!
      authenticate_or_request_with_http_token do |token, _options|
        @current_api_user = User.find_by(api_token: token)
        Current.user = @current_api_user if @current_api_user
        @current_api_user.present?
      end
    end

    # For endpoints open to anyone: a token, when sent, still says who is asking
    # (so each app gets its own rate limit rather than sharing its server's IP).
    def identify_api_user
      authenticate_with_http_token do |token, _options|
        @current_api_user = User.find_by(api_token: token)
      end
    end

    attr_reader :current_api_user
  end
end
