# frozen_string_literal: true

module VoiceCloning
  # Renders a single ClonedAudioRendition: opens the source's audio, runs
  # the Voice Changer, and attaches the result to the rendition.
  class RenderRenditionService
    class Error < StandardError; end

    def initialize(rendition, changer: nil)
      @rendition = rendition
      @changer = changer
    end

    def call
      voice_user = @rendition.voice_user
      raise Error, "voice_user has no cloned_voice_id" unless voice_user.cloned_voice?

      source_media = @rendition.source.media
      raise Error, "source has no attached media" unless source_media.attached?

      @rendition.update!(status: :pending, error_message: nil)

      changer = @changer || VoiceChangerService.new(voice_id: voice_user.cloned_voice_id)

      source_media.open do |source_file|
        bytes = changer.call(source_path: source_file.path)
        attach_result(bytes)
      end

      @rendition.update!(status: :ready)
      @rendition
    rescue => e
      @rendition.update(status: :failed, error_message: e.message)
      raise
    end

    private

    def attach_result(bytes)
      Tempfile.create(["rendition_#{@rendition.id}", ".mp3"], binmode: true) do |out|
        out.write(bytes)
        out.rewind
        @rendition.media.attach(
          io: out,
          filename: rendition_filename,
          content_type: "audio/mpeg"
        )
      end
    end

    def rendition_filename
      base = "#{@rendition.source_type.underscore}_#{@rendition.source_id}_voice_#{@rendition.voice_user_id}"
      "#{base}.mp3"
    end
  end
end
