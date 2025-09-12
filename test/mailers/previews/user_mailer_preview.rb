# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset_email
  def password_reset_email
    user = User.order(updated_at: :desc).first
    UserMailer.password_reset_email(user)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/new_user_email
  def new_user_email
    user = User.order(updated_at: :desc).first
    UserMailer.new_user_email(user)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/broadcast_email
  def broadcast_email
    user = User.order(updated_at: :desc).first
    subject = "Fógra Tábhachtach ó Abairt"
    message = "Dia dhaoibh a chairde,\n\nTá feabhsúcháin nua curtha leis an suíomh. Bígí cinnte breathnú orthu!\n\nGo raibh míle maith agaibh as bhur dtacaíocht leanúnach.\n\nSlán go fóill,\nFoireann Abairt"
    UserMailer.broadcast_email(user, subject, message)
  end

end
