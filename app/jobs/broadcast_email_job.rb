class BroadcastEmailJob < ApplicationJob
  queue_as :default

  def perform(subject, message)
    User.active.find_each do |user|
      UserMailer.broadcast_email(user, subject, message).deliver_now
    end
  end
end
