namespace :cron do
  desc "Recurring tasks"
  task ceisteanna: :environment do
    User.with_unanswered_ceisteanna.each do |user|
      NotificationsMailer.with(user: user).ceisteanna.deliver
    end
  end

  task ceád_rang_eile: :environment do
    # Rangs happening tomorrow
    Rang.where("date_trunc('day', rangs.time) = date_trunc('day', current_date + interval '1' day)").each do |rang|
      NotificationsMailer.with(rang: rang).ceád_rang_eile
    end
  end
end
