# frozen_string_literal: true

class LoginRequestsController < ApplicationController
  skip_after_action :verify_authorized

  def new
    redirect_to root_path if current_user
  end

  def create
    if user = User.find_by(email: params[:email])
      user.regenerate_login_token
      user.save!
      UserMailer.login_email(user).deliver_now
    end
    flash[:notice] = 'Check your email for login link.'
    redirect_to login_path
  end
end
