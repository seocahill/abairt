class RegistrationsController < ApplicationController
  layout 'centered_layout'

  def new
    @user = User.new
    authorize @user, policy_class: RegistrationPolicy
  end

  def create
    # FIXME no need to perform authorization if bot detected.
    if params["bot-field"].present?
      authorize User.new, policy_class: RegistrationPolicy
      redirect_to root_path
    else
      @user = User.new(user_params.merge(password: SecureRandom.hex(32)))
      authorize @user, policy_class: RegistrationPolicy
      if @user.save
        UserMailer.new_user_email(@user).deliver
        redirect_to root_path, notice: 'Thanks for signing up.'
      else
        render :new
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :about)
  end
end
