# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def password_reset_email(user)
    @user = user
    mail(to: @user.email, subject: 'Password Reset Instructions')
  end

  def new_user_email(user)
    @user = user
    mail(to: User.admin.pluck(:email), subject: 'New User Signed up')
  end
end
