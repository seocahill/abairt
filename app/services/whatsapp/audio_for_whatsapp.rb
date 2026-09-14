# frozen_string_literal: true

module Whatsapp
  # Yields a path to an ogg/opus copy of an attachment, ready to upload.
  #
  #   Whatsapp::AudioForWhatsapp.new(question.audio).open { |path| ... }
  #
  # WhatsApp renders ogg/opus as a playable voice bubble and everything else as
  # a file attachment. A file attachment is a dead end for the audience this is
  # built for, so the format is not optional.
  #
  # Browsers record webm/opus, which is the same audio in a different container
  # — so the usual case is a stream copy rather than a re-encode.
  class AudioForWhatsapp
    OGG_CONTENT_TYPE = "audio/ogg"

    class TranscodeError < StandardError; end

    def initialize(attachment)
      @attachment = attachment
    end

    def open(&block)
      @attachment.open do |source|
        next block.call(source.path) if already_ogg?

        Tempfile.create(["whatsapp_audio", ".ogg"], binmode: true) do |output|
          transcode(source.path, output.path)
          block.call(output.path)
        end
      end
    end

    private

    def already_ogg?
      @attachment.content_type.to_s.start_with?(OGG_CONTENT_TYPE)
    end

    def transcode(input, output)
      return if copy_opus(input, output)
      return if encode_opus(input, output)

      raise TranscodeError, "ffmpeg could not produce ogg/opus from #{@attachment.content_type}"
    end

    # webm/opus and ogg/opus hold identical audio, so remux without re-encoding.
    def copy_opus(input, output)
      ffmpeg(input, "-c:a", "copy", "-f", "ogg", output)
    end

    def encode_opus(input, output)
      ffmpeg(input, "-c:a", "libopus", "-b:a", "32k", "-ac", "1", "-f", "ogg", output)
    end

    def ffmpeg(input, *args, output)
      system("ffmpeg", "-y", "-i", input, "-vn", *args, output, err: File::NULL) &&
        File.size?(output).present?
    end
  end
end
