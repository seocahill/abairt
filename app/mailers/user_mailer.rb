# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def password_reset_email(user)
    @user = user
    mail(to: @user.email, subject: 'Login link')
  end

  def new_user_email(user)
    @user = user
    mail(to: User.admin.pluck(:email), subject: 'New User Signed up')
  end

  def broadcast_email(user, subject, message)
    @user = user
    @message = message
    mail(to: @user.email, subject: subject)
  end
end
