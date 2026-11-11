# frozen_string_literal: true

module Api
  # Step one of signing in to an app: ask for a link by email. It answers the
  # same whether or not the address belongs to an approved account, so it
  # cannot be used to find out who has one.
  class LoginRequestsController < BaseController
    skip_before_action :authenticate_api_token!

    rate_limit to: 5, within: 15.minutes, by: -> { params[:email].to_s.strip.downcase }, name: "per_email"
    rate_limit to: 30, within: 1.hour, by: -> { request.remote_ip }, name: "per_ip"

    # POST /api/login_requests  { email }
    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase)
      if user&.confirmed?
        user.regenerate_login_token
        UserMailer.app_login_email(user).deliver_now
      end

      head :accepted
    end
  end
end
