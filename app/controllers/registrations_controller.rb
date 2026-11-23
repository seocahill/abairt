class RegistrationsController < ApplicationController
  layout "centered_layout"

  # Slows down scripted sign-ups. Backed by Rails.cache, which is Redis in
  # production and a null store in development and test.
  rate_limit to: 10, within: 1.hour, only: :create,
    with: -> { redirect_to new_registration_path, alert: "Too many sign-ups from this connection. Please try again later." }

  def new
    @user = User.new
    authorize @user, policy_class: RegistrationPolicy
    # Starts the bot timer once per form load; a failed create keeps it.
    session[:form_start_time] = Time.current
  end

  def create
    if bot_detected?
      authorize User.new, policy_class: RegistrationPolicy
      redirect_to root_path
      return
    end

    @user = User.new(user_params)
    authorize @user, policy_class: RegistrationPolicy
    if @user.save
      UserMailer.new_user_email(@user).deliver_later
      UserMailer.signup_pending_email(@user).deliver_later
      redirect_to root_path, notice: "Thanks for signing up."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def bot_detected?
    return true if params["bot-field"].present?
    return true if params["website"].present? || params["phone"].present? || params["company"].present?
    submission_too_fast? || submission_too_slow?
  end

  def submission_too_fast?
    form_elapsed&.<(3.seconds)
  end

  def submission_too_slow?
    form_elapsed&.>(10.minutes)
  end

  def form_elapsed
    return unless session[:form_start_time]
    Time.current - Time.zone.parse(session[:form_start_time].to_s)
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
