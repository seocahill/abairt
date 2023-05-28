# Preview all emails at http://localhost:3000/rails/mailers/notifications_mailer
class NotificationsMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/notifications_mailer/recent_messages
  def recent_messages
    NotificationsMailer.with(user: User.first).recent_messages
  end
end
