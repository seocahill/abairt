# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :verify_authenticity_token, only: :create
  layout 'centered_layout'

  def new
    redirect_to root_path if current_user
  end

  def create
    @user = User.find_by(password_reset_token: params[:token])
    if @user.nil? || @user.password_reset_token_expired?
      flash[:alert] = 'Invalid password reset link.'
      redirect_to login_path
    else
      @user.clear_password_reset_token
      session[:user_id] = @user.id
      flash[:notice] = 'Login successful.'
      redirect_to user_path(@user)
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path
  end
end
