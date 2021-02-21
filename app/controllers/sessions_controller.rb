# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    @user = User.create(params.require(:user).permit(:username, :password))
    session[:user_id] = @user.id
    redirect_to @user
  end
end
