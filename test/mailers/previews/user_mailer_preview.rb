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
    email = Email.last
    if email.nil?
      # Create a sample rich content for preview
      email = Email.new(subject: "Fógra Tábhachtach ó Abairt")
      email.rich_content = ActionText::Content.new("<p>Dia dhaoibh a chairde,</p><p>Tá <strong>feabhsúcháin nua</strong> curtha leis an suíomh. Bígí cinnte breathnú orthu!</p><p>Go raibh míle maith agaibh as bhur dtacaíocht leanúnach.</p><p>Slán go fóill,<br>Foireann Abairt</p>")
    end
    UserMailer.broadcast_email(user, email.subject, email.rich_content)
  end

end
