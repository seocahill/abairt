# frozen_string_literal: true

module Api
  # Step two of signing in to an app: swap the token from the emailed link for
  # the account's API token. The link works once, for fifteen minutes.
  class SessionsController < BaseController
    skip_before_action :authenticate_api_token!

    rate_limit to: 20, within: 15.minutes, by: -> { request.remote_ip }

    # POST /api/sessions  { token }
    def create
      user = User.find_by_token_for(:app_login, params[:token].to_s)
      return render(json: {error: "This link has expired or was already used"}, status: :unauthorized) unless user&.confirmed?

      user.regenerate_login_token # the link cannot be used again
      user.regenerate_api_token if user.api_token.blank?

      render json: {api_token: user.api_token, name: user.name}
    end
  end
end
