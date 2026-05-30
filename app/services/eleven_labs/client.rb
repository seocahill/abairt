# frozen_string_literal: true

module ElevenLabs
  # Thin wrapper around the ElevenLabs HTTP API.
  # Only the endpoints needed by the voice-cloning workflow are exposed:
  #   * add_voice          - Instant Voice Cloning from sample files
  #   * delete_voice       - remove a voice from the workspace
  #   * speech_to_speech   - Voice Changer (audio -> audio in target voice)
  class Client
    include HTTParty

    base_uri "https://api.elevenlabs.io/v1"

    SPEECH_TO_SPEECH_MODEL = "eleven_multilingual_sts_v2"

    class Error < StandardError; end

    def initialize(api_key: nil)
      @api_key = api_key || default_api_key
      raise Error, "ELEVENLABS_API_KEY is not configured" if @api_key.blank?
    end

    # POST /v1/voices/add  (multipart)
    # Returns the voice_id of the newly created voice.
    def add_voice(name:, sample_paths:, description: nil, labels: {})
      files = sample_paths.map { |path| File.open(path, "rb") }

      response = self.class.post(
        "/voices/add",
        headers: {"xi-api-key" => @api_key},
        body: {
          name: name,
          description: description.to_s,
          labels: labels.to_json,
          files: files
        },
        multipart: true
      )

      raise Error, "ElevenLabs add_voice failed: #{response.code} #{response.body}" unless response.success?

      response.parsed_response.fetch("voice_id")
    ensure
      files&.each { |io|
        begin
          io.close
        rescue
          nil
        end
      }
    end

    # DELETE /v1/voices/:voice_id
    def delete_voice(voice_id)
      response = self.class.delete(
        "/voices/#{voice_id}",
        headers: {"xi-api-key" => @api_key}
      )

      response.success? || response.code == 404
    end

    # POST /v1/speech-to-speech/:voice_id  (multipart)
    # Returns raw audio bytes (mp3) of the converted output.
    def speech_to_speech(voice_id:, source_path:, model_id: SPEECH_TO_SPEECH_MODEL)
      File.open(source_path, "rb") do |io|
        response = self.class.post(
          "/speech-to-speech/#{voice_id}",
          headers: {"xi-api-key" => @api_key},
          body: {audio: io, model_id: model_id},
          multipart: true
        )

        unless response.success?
          raise Error, "ElevenLabs speech_to_speech failed: #{response.code} #{response.body}"
        end

        response.body
      end
    end

    private

    def default_api_key
      Rails.application.credentials.dig(:elevenlabs, :api_key) || ENV["ELEVENLABS_API_KEY"]
    end
  end
end
