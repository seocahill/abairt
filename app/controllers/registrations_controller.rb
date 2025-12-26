class RegistrationsController < ApplicationController
  layout 'centered_layout'

  def new
    @user = User.new
    authorize @user, policy_class: RegistrationPolicy
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
      UserMailer.new_user_email(@user).deliver
      redirect_to root_path, notice: 'Thanks for signing up.'
    else
      render :new
    end
  end

  private

  def bot_detected?
    return true if params["bot-field"].present?
    return true if params["website"].present? || params["phone"].present? || params["company"].present?
    return true if submission_too_fast? || submission_too_slow?
    false
  end

  def submission_too_fast?
    return false unless session[:form_start_time]
    elapsed = Time.current - Time.parse(session[:form_start_time].to_s)
    elapsed < 3.seconds
  end

  def submission_too_slow?
    return false unless session[:form_start_time]
    elapsed = Time.current - Time.parse(session[:form_start_time].to_s)
    elapsed > 10.minutes
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :about)
  end
end
