# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset_email
  def password_reset_email
    user = User.order(updated_at: :desc).first
    UserMailer.password_reset_email(user)
  end

   # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset_email
  def new_user_email
    user = User.order(updated_at: :desc).first
    UserMailer.new_user_email(user)
  end

end
