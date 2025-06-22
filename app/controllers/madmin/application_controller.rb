module Madmin
  class ApplicationController < Madmin::BaseController
    include Authentication

    before_action :authenticate_admin_user

    def authenticate_admin_user
      redirect_to "/", alert: "Not authorized." unless Current&.user&.admin?
    end
  end
end
