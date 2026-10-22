# frozen_string_literal: true

module Telegram
  # Sends one segment to a speaker to be checked.
  #
  #   Telegram::DeliverSegment.new(entry, speaker).call # => message id, or nil
  #
  # The clip, the transcription as it currently stands, and one button. Two ways
  # to answer and nothing to read: tap the button if it is right, or hold the
  # mic and say what was actually said.
  class DeliverSegment
    # Also what ProcessInbound matches an incoming tap against, so the two stay
    # in step.
    CONFIRM = "Tá sé ceart"
    ASK = "An bhfuil sé seo ceart?"
    NO_TEXT = "(níl aon téacs air seo)"

    def initialize(entry, speaker, client: Client.new)
      @entry = entry
      @speaker = speaker
      @client = client
    end

    def call
      message_id = OpusVoiceNote.new(@entry.media).open do |path|
        @client.send_voice(
          chat_id: @speaker.telegram_chat_id,
          path: path,
          caption: caption,
          button: CONFIRM
        )
      end

      "telegram:#{@speaker.telegram_chat_id}:#{message_id}"
    rescue Client::Error, OpusVoiceNote::TranscodeError => e
      # The segment is simply offered again next time rather than wedging the
      # queue on one bad clip.
      Rails.logger.error("DeliverSegment failed for DictionaryEntry##{@entry.id}: #{e.message}")
      nil
    end

    private

    def caption
      "#{@entry.word_or_phrase.presence || NO_TEXT}\n\n#{ASK}"
    end
  end
end
