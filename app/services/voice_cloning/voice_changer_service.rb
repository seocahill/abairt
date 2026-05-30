# frozen_string_literal: true

module VoiceCloning
  # Runs an ElevenLabs Speech-to-Speech conversion: takes the audio bytes of
  # a source clip and returns audio bytes rendered in the target voice.
  # The source's prosody / phonemes are preserved, only timbre is swapped.
  class VoiceChangerService
    class Error < StandardError; end

    def initialize(voice_id:, client: nil)
      @voice_id = voice_id
      @client = client || ElevenLabs::Client.new
    end

    # source_path: a local audio file path
    # returns mp3 bytes
    def call(source_path:)
      raise Error, "source file missing: #{source_path}" unless File.exist?(source_path)

      @client.speech_to_speech(voice_id: @voice_id, source_path: source_path)
    end
  end
end
