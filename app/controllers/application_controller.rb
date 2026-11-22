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

  helper_method :current_user, :admin_user?, :admin_page?, :search_to_moment?, :simple_signup?
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

  def admin_page?
    controller_path.start_with?("admin/") || controller_path == "admin_emails"
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

  # Search results open recordings at the matching line (flag f170).
  def search_to_moment?
    return @search_to_moment if defined?(@search_to_moment)
    @search_to_moment = Flipper.enabled?(:f170_search_to_moment, current_user)
  end

  # Search also finds mutated Irish spellings and half-typed words (flag f171).
  def mutation_search?
    return @mutation_search if defined?(@mutation_search)
    @mutation_search = Flipper.enabled?(:f171_mutation_search, current_user)
  end

  # Simpler sign-up and a password link on your own profile (flag f121).
  def simple_signup?
    return @simple_signup if defined?(@simple_signup)
    @simple_signup = Flipper.enabled?(:f121_simple_signup, current_user)
  end

  private

  def rails_engine_controller?
    # Skip Pundit verification for Rails engine controllers
    # Mission Control and other engines have their own authorization
    self.class.name.start_with?("MissionControl::")
  end
end
