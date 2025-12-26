# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Authentication
  include SetCurrentRequestDetails
  include Pundit::Authorization

  unless Rails.env.production?
    include ActiveStorage::SetCurrent
  end

  PAGE_SIZE = 15

  helper_method :current_user, :admin_user?
  before_action :set_paper_trail_whodunnit
  after_action :verify_authorized, except: [:index, :show]

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def user_not_authorized
    redirect_back(fallback_location: root_path, alert: "Caithfidh tú a bheith sínithe isteach!")
  end

  def current_user
    User.where(confirmed: true).find_by(id: session[:user_id])
  end

  def admin_user?
    user = User.find_by(id: session[:user_id])
    user&.admin?
  end

  def root_redirect
    authorize User
    if current_user
      redirect_to user_path(current_user)
    else
      redirect_to home_path
    end
  end
end
