class NotificationsMailer < ApplicationMailer
  default from: 'info@abairt.com'

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

  def transcription_failed(voice_recording, error_message)
    @voice_recording = voice_recording
    @error_message = error_message
    @url = voice_recording_url(voice_recording)

    mail(
      to: "seosamh@seocahill.com",
      subject: "Transcription Failed: #{voice_recording.title}"
    )
  end
end
