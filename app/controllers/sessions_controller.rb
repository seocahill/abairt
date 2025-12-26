# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :verify_authenticity_token, only: :create
  layout 'centered_layout'

  def new
    redirect_to root_path if current_user
  end

  def create
    @user = User.find_by(login_token: params[:token])
    if @user.nil?
      flash[:alert] = 'Invalid login link.'
      redirect_to login_path
    else
      @user.regenerate_login_token # Regenerate token after use (one-time use)
      @user.save!
      session[:user_id] = @user.id
      flash[:notice] = 'Login successful.'
      redirect_to user_path(@user)
    end
  end

  def login_with_token
    @user = User.find_by(login_token: params[:token])
    if @user.nil?
      flash[:alert] = 'Invalid login link.'
      redirect_to login_path
    else
      @user.regenerate_login_token # Regenerate token after use (one-time use)
      @user.save!
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
