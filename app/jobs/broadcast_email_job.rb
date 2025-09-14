class BroadcastEmailJob < ApplicationJob
  queue_as :default

  def perform(email_id)
    email = Email.find(email_id)
    
    User.active.find_each do |user|
      UserMailer.broadcast_email(user, email.subject, email.rich_content).deliver_now
    end
  end
end
