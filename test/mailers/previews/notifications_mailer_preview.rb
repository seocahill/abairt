# Preview all emails at http://localhost:3000/rails/mailers/notifications_mailer
class NotificationsMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/notifications_mailer/ceisteanna
  def ceisteanna
    NotificationsMailer.ceisteanna
  end

  # Preview this email at http://localhost:3000/rails/mailers/notifications_mailer/ceád_rang_eile
  def ceád_rang_eile
    NotificationsMailer.ceád_rang_eile
  end

end
