# frozen_string_literal: true

# Lets a signed-in user set or change their password.
#
# Signing in once by magic link and then setting a password is how you stop
# needing the magic link — which matters on a phone, where fetching a link from
# email mid-task is the thing that kills the whole interaction.
class PasswordsController < ApplicationController
  before_action :require_login
  skip_after_action :verify_authorized

  def edit
  end

  def update
    if current_user.update(password_params)
      remember(current_user)
      redirect_to new_question_path, notice: "Focal faire socraithe."
    else
      @errors = current_user.errors.full_messages
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def require_login
    redirect_to login_path, alert: "Caithfidh tú a bheith sínithe isteach!" unless current_user
  end
end
