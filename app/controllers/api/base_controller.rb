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

    def current_api_user
      @current_api_user
    end
  end
end

