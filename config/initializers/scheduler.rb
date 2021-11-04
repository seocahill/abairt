#
# config/initializers/scheduler.rb

require 'rufus-scheduler'

return if defined?(Rails::Console) || Rails.env.test? || File.split($PROGRAM_NAME).last == 'rake'
  #
  # do not schedule when Rails is run from its console, for a test/spec, or
  # from a Rake task

# return if $PROGRAM_NAME.include?('spring')
  #
  # see https://github.com/jmettraux/rufus-scheduler/issues/186

s = Rufus::Scheduler.singleton
# scheduler.cron '00 09 * * *'  9am
s.cron '00 09 * * *' do
  Rang.where("strftime('%m-%d-%Y', rangs.time) = strftime('%m-%d-%Y', 'now')").each do |rang|
    NotificationsMailer.with(rang: rang).ceád_rang_eile.deliver
  end
end
