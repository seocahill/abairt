# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset_email
  def password_reset_email
    UserMailer.password_reset_email(User.first)
  end

   # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset_email
  def new_user_email
    UserMailer.new_user_email(User.last)
  end

end
