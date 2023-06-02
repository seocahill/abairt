# app/controllers/password_resets_controller.rb
class PasswordResetsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:email])
    if user
      user.generate_password_reset_token
      user.save
      UserMailer.password_reset_email(user).deliver_now
      flash[:notice] = 'Password reset instructions have been sent to your email.'
      redirect_to login_path
    else
      flash.now[:alert] = 'Email address not found.'
      render :new
    end
  end

  def edit
    @user = User.find_by(password_reset_token: params[:token])
    if @user.nil? || @user.password_reset_token_expired?
      flash[:alert] = 'Invalid password reset link.'
      redirect_to login_path
    end
  end

  def update
    @user = User.find_by(password_reset_token: params[:token])
    if @user.nil? || @user.password_reset_token_expired?
      flash[:alert] = 'Invalid password reset link.'
      redirect_to login_path
    elsif @user.update(user_params)
      @user.clear_password_reset_token
      flash[:notice] = 'Your password has been successfully reset. Please log in with your new password.'
      redirect_to login_path
    else
      render :edit
    end
  end

  private

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
