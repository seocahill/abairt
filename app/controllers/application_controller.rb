# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Backend

  helper_method :current_user

  def current_user
    User.find_by(id: session[:user_id], confirmed: true)
  end
end
