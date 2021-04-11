namespace :cron do
  desc "Recurring tasks"
  task ceisteanna: :environment do
    User.with_unanswered_ceisteanna.each do |user|
      NotificationsMailer.with(user: user).ceisteanna.deliver
    end
  end

  task ceád_rang_eile: :environment do
     NotificationsMailer.ceád_rang_eile
  end
end
