# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Authentication
  include SetCurrentRequestDetails
  PAGE_SIZE = 15

  helper_method :current_user

  before_action do
    asset_url = ENV.fetch("ASSET_HOST", request.url)
    ActiveStorage::Current.host = asset_url
  end

  def authorize
    return if current_user

    redirect_back(fallback_location: root_path, alert: "Caithfidh tú a bheith sínithe isteach!")
  end

  def current_user
    User.find_by(id: session[:user_id])
  end
end
