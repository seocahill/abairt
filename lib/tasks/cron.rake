namespace :cron do
  desc "Recurring tasks"
  task ceisteanna: :environment do
    User.with_unanswered_ceisteanna.each do |user|
      NotificationsMailer.with(user: user).ceisteanna.deliver
    end
  end

  task cead_rang_eile: :environment do
    # Rangs happening tomorrow
    Rang.where("strftime('%m-%d-%Y', rangs.time) = strftime('%m-%d-%Y', 'now', '+1 day')").each do |rang|
      NotificationsMailer.with(rang: rang).ceád_rang_eile.deliver
    end
  end

  task ranganna_inniu: :environment do
    # Rangs happening today
    Rang.where("strftime('%m-%d-%Y', rangs.time) = strftime('%m-%d-%Y', 'now')").each do |rang|
      NotificationsMailer.with(rang: rang).ceád_rang_eile.deliver
    end
  end
end
