class NotificationsMailer < ApplicationMailer
  default from: 'abairt@abairt.com'

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications_mailer.ceisteanna.subject
  #
  def ceisteanna
    @user = params[:user]
    mail(to: @user.email, subject: 'Tá ceisteanna ag fanacht duit')
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notifications_mailer.ceád_rang_eile.subject
  #
  def ceád_rang_eile
    @rang = params[:rang]
    mail(to: @rang.participants, subject: 'An chéad rang eile')
  end
end
