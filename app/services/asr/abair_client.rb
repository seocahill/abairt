# frozen_string_literal: true

module Asr
  # Sends an audio file to the abair.ie recogniser and returns its text, or nil.
  class AbairClient
    URL = "https://phoneticsrv3.lcs.tcd.ie/asr_api/recognise"
    PROVIDER = "abair"
    MODEL = "online2bin"

    def self.transcribe(file_path)
      new(file_path).transcribe
    end

    def initialize(file_path)
      @file_path = file_path
    end

    def transcribe
      Rails.logger.info("Starting transcription request to abair.ie API")

      uri = URI.parse(URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 30
      request = Net::HTTP::Post.new(uri.path)
      request.body = {recogniseBlob: AudioBlob.wav_base64(@file_path), developer: true, method: MODEL}.to_json
      request["Content-Type"] = "application/json"

      response = http.request(request)
      Rails.logger.info("Transcription API response: #{response.code}")

      if %w[429 503].include?(response.code)
        Rails.logger.warn("API rate limited, sleeping before retry")
        sleep(5)
        raise "Rate limited by abair.ie API"
      end

      JSON.parse(response.body).dig("transcriptions", 0, "utterance")
    rescue => e
      Rails.logger.error("Transcription failed: #{e.message}")
      nil
    end
  end
end
