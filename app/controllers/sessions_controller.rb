# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_after_action :verify_authorized
  skip_before_action :verify_authenticity_token, only: :create
  layout "centered_layout"

  # Guesses against a password are cheap without this. Backed by Rails.cache,
  # which is a file store in production and a null store in development and
  # test — so this protects the deployed app and is inert locally.
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to login_path, alert: "An iomarca iarrachtaí. Fan nóiméad." }

  def new
    redirect_to root_path if current_user
  end

  # Two ways in: a password, or the magic link token. Both end up signed in and
  # remembered on this device.
  def create
    params[:password].present? ? sign_in_with_password : sign_in_with_token
  end

  # The magic link itself. Same handling as a pasted token.
  def login_with_token
    sign_in_with_token
  end

  def destroy
    forget(current_user)
    session[:user_id] = nil
    redirect_to root_path
  end

  private

  def sign_in_with_password
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      sign_in(user)
      redirect_to(session.delete(:user_return_to) || new_question_path)
    else
      Rails.logger.warn("Failed password login")
      flash[:alert] = "Níorbh fhéidir tú a shíniú isteach. Seiceáil an ríomhphost agus an focal faire."
      redirect_to login_path
    end
  end

  def sign_in_with_token
    @user = User.find_by(login_token: params[:token]&.strip)

    if @user.nil?
      Rails.logger.warn("Failed login attempt with an invalid token")
      flash[:alert] = "Invalid login link. Please request a new one."
      redirect_to login_path
    else
      # Regenerated so a link cannot be replayed. Concurrent requests carrying
      # the same token all land before this, which is why it is not done first.
      @user.regenerate_login_token
      @user.save

      sign_in(@user)
      redirect_to(session.delete(:user_return_to) || user_path(@user))
    end
  end

  def sign_in(user)
    session[:user_id] = user.id
    remember(user)
    Rails.logger.info("Successful login for user #{user.id}")
    flash[:notice] = "Login successful."
  end
end
