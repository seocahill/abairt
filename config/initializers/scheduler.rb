#
# config/initializers/scheduler.rb

require 'rufus-scheduler'

return if defined?(Rails::Console) || Rails.env.test? || Rails.env.development? || File.split($PROGRAM_NAME).last == 'rake'
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

# Monitor TTS and ASR services every hour
s.cron '0 * * * *' do
  MonitorServicesJob.perform_later
end

# Nightly job to diarize the last un-diarized voice recording
s.cron '0 2 * * *' do
  NightlyTranscribeJob.perform_later
end
