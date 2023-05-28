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
  User.each do |user|
    next unless user.recent_messages.any?

    NotificationsMailer.with(user: user).recent_messages.deliver
  end
end
