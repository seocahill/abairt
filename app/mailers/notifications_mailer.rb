class NotificationsMailer < ApplicationMailer
  default from: 'abairt@abairt.com'

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications_mailer.ceisteanna.subject
  #

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications_mailer.ceád_rang_eile.subject
  #
  def recent_messages
    @user = params[:user]
    @messages = @user.recent_messages
    mail(to: @user.email, subject: "You have received #{@messages.size} messages since yesterday")
  end
end
