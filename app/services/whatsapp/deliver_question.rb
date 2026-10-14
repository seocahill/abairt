# frozen_string_literal: true

module Whatsapp
  # Sends one question to the speaker as a voice note.
  #
  #   Whatsapp::DeliverQuestion.new(question).call # => message id, or nil
  #
  # Returns the message id when the question actually reached them, and nil when
  # it did not — in which case the question stays `waiting` and will go out on
  # the next attempt.
  #
  # The nil case is the 24 hour window. WhatsApp only allows free-form messages
  # (audio included) within 24 hours of the speaker's last message to us, and
  # templates — the only thing allowed outside it — cannot carry audio. So when
  # the window is shut we send a nudge template with a button instead; one tap
  # reopens the window and the audio follows immediately.
  class DeliverQuestion
    NUDGE_TEMPLATE = "ceist_nua"
    # Don't nudge more than this often, however long the backlog is. A pile-up
    # of notifications is exactly what makes someone stop opening the app.
    NUDGE_INTERVAL = 12.hours

    def initialize(question, client: Client.new)
      @question = question
      @speaker = question.speaker
      @client = client
    end

    def call
      return nudge unless @speaker.whatsapp_window_open?

      wamid = @client.send_audio(to: @speaker.phone_number, media_id: upload)
      "whatsapp:#{wamid}"
    rescue Client::Error, OpusVoiceNote::TranscodeError => e
      # Leave the question waiting rather than wedging the queue on one bad file.
      Rails.logger.error("DeliverQuestion failed for Question##{@question.id}: #{e.message}")
      nil
    end

    private

    def upload
      OpusVoiceNote.new(@question.audio).open do |path|
        @client.upload_media(path)
      end
    end

    # Returns nil: a nudge is not a delivery. The question stays waiting until
    # the speaker taps through and we can send the audio itself.
    def nudge
      return nil if nudged_recently?

      @client.send_template(to: @speaker.phone_number, name: NUDGE_TEMPLATE)
      @speaker.update!(whatsapp_nudged_at: Time.current)
      nil
    end

    def nudged_recently?
      @speaker.whatsapp_nudged_at.present? && @speaker.whatsapp_nudged_at > NUDGE_INTERVAL.ago
    end
  end
end
