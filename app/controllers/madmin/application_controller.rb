module Madmin
  class ApplicationController < Madmin::BaseController
    include Authentication

    before_action :authenticate_admin_user

    def authenticate_admin_user
      redirect_to "/", alert: "Not authorized." unless Current&.user&.admin?
    end

    # Authenticate with Clearance
    # include Clearance::Controller
    # before_action :require_login

    # Authenticate with Devise
    # before_action :authenticate_user!

    # Authenticate with Basic Auth
    # http_basic_authenticate_with(name: Rails.application.credentials.admin_username, password: Rails.application.credentials.admin_password)
  end
end
