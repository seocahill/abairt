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
  after_action :verify_authorized, except: [:index, :show], unless: :rails_engine_controller?

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

  def ensure_admin
    user = User.find_by(id: session[:user_id])
    unless user&.admin?
      redirect_to root_path, alert: 'Ní féidir leat an leathanach sin a rochtain.'
    end
  end

  private

  def rails_engine_controller?
    # Skip Pundit verification for Rails engine controllers
    # Mission Control and other engines have their own authorization
    self.class.name.start_with?("MissionControl::")
  end
end
