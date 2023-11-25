class RegistrationsController < ApplicationController
  layout 'centered_layout'

  def new
    @user = User.new
    authorize @user, policy_class: RegistrationPolicy
  end

  def create
    @user = User.new(user_params.merge(password: SecureRandom.uuid))
    authorize @user, policy_class: RegistrationPolicy
    if @user.save
      UserMailer.new_user_email(@user).deliver
      redirect_to root_path, notice: 'Thanks for signing up.'
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :about)
  end
end
