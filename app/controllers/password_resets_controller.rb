# app/controllers/password_resets_controller.rb
class PasswordResetsController < ApplicationController
  skip_after_action :verify_authorized

  def new
    redirect_to root_path if current_user
  end

  def create
    if user = User.find_by(email: params[:email])
      user.generate_password_reset_token
      user.save
      UserMailer.password_reset_email(user).deliver_now
    end
    flash[:notice] = 'Check your email for login link.'
    redirect_to login_path
  end

  private

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
