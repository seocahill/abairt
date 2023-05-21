# Preview all emails at http://localhost:3000/rails/mailers/notifications_mailer
class NotificationsMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/notifications_mailer/ceád_rang_eile
  def ceád_rang_eile
    NotificationsMailer.with(rang: Rang.where.not(time: nil).first).ceád_rang_eile
  end

end
