class BroadcastEmailJob < ApplicationJob
  queue_as :default

  def perform(email_id, user_id = nil)
    email = Email.find(email_id)

    if user_id
      # Send to specific user only (for testing)
      user = User.find(user_id)
      UserMailer.broadcast_email(user, email.subject, email.rich_content).deliver_now
    else
      # Send to confirmed, non-speaker, non-AI users without @abairt.com emails
      eligible_users.find_each do |user|
        UserMailer.broadcast_email(user, email.subject, email.rich_content).deliver_now
      end
    end
  end

  private

  def eligible_users
    User.active
        .where(confirmed: true)
        .where.not(role: [:speaker, :ai, :place, :temporary])
        .where.not("email LIKE ?", "%@abairt.com")
  end
end
