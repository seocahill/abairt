# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Authentication
  include SetCurrentRequestDetails

  helper_method :current_user

  def current_user
    User.find_by(id: session[:user_id], confirmed: true)
  end

  before_action do
    current_host = request.url || "http://localhost:3000"
    ActiveStorage::Current.host = current_host
  end
end
