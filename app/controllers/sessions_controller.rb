# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :verify_authenticity_token, only: :create
  layout 'centered_layout'

  def new
    redirect_to root_path if current_user
  end

  def create
    token = params[:token]&.strip
    @user = User.find_by(login_token: token)

    if @user.nil?
      Rails.logger.warn("Failed login attempt with token: #{token&.truncate(10)}")
      flash[:alert] = 'Invalid login link. Please request a new one.'
      redirect_to login_path
    else
      # Allow login and set session
      session[:user_id] = @user.id
      Rails.logger.info("Successful login for user: #{@user.email}")

      # Regenerate token in background (non-blocking)
      # This way concurrent requests all succeed before token is regenerated
      @user.regenerate_login_token
      @user.save

      flash[:notice] = 'Login successful.'
      redirect_to user_path(@user)
    end
  end

  def login_with_token
    token = params[:token]&.strip
    @user = User.find_by(login_token: token)

    if @user.nil?
      Rails.logger.warn("Failed login attempt with token: #{token&.truncate(10)}")
      flash[:alert] = 'Invalid login link. Please request a new one.'
      redirect_to login_path
    else
      # Allow login and set session
      session[:user_id] = @user.id
      Rails.logger.info("Successful login for user: #{@user.email}")

      # Regenerate token in background (non-blocking)
      # This way concurrent requests all succeed before token is regenerated
      @user.regenerate_login_token
      @user.save

      flash[:notice] = 'Login successful.'
      redirect_to user_path(@user)
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path
  end
end
