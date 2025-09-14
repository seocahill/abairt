class BroadcastEmailJob < ApplicationJob
  queue_as :default

  def perform(email_id, user_id = nil)
    email = Email.find(email_id)

    if user_id
      # Send to specific user only (for testing)
      user = User.find(user_id)
      UserMailer.broadcast_email(user, email.subject, email.rich_content).deliver_now
    else
      # Send to all active users
      User.active.find_each do |user|
        UserMailer.broadcast_email(user, email.subject, email.rich_content).deliver_now
      end
    end
  end
end
