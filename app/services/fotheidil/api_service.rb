# frozen_string_literal: true

module Fotheidil
  # Client for the Abair API v4 subtitles pipeline (https://api.abair.ie/v4/docs).
  #
  # Replaces the browser automation that previously drove fotheidil.abair.ie:
  # submit media, poll for progress, fetch the finished transcript. Segments come
  # back in the same shape the scraper used to extract from the page.
  #
  #   service = Fotheidil::ApiService.new
  #   id = service.submit("/tmp/interview.mp3", file_name: "interview.mp3")
  #   service.transcript(id) # => [{"startTimeSeconds" => 0.57, ...}] or nil while processing
  class ApiService
    class Error < StandardError; end

    BASE_URL = "https://api.abair.ie/v4"

    def initialize(api_key = nil)
      @api_key = api_key || self.class.api_key
    end

    def self.api_key
      Rails.application.credentials.dig(:abair, :api_key) || ENV["ABAIRT_API_KEY"]
    end

    # Queues a transcription job and returns its id.
    #
    # The API derives the stored media name from file_name and rejects a name it
    # already holds with "audio already uploaded", so callers must pass a name
    # unique to this submission.
    def submit(file_path, file_name:)
      raise Error, "File not found: #{file_path}" unless File.exist?(file_path)

      File.open(file_path) do |file|
        response = request(:post, "/subtitles", multipart: true, body: {file:, fileName: file_name})
        id = response["id"]
        raise Error, "No job id returned: #{response}" if id.blank?

        Rails.logger.info "Fotheidil job #{id} queued for #{file_name}"
        id
      end
    end

    # Progress of a queued job: status, audio_extraction_progress,
    # recognition_progress, media_length.
    def status(id)
      request(:get, "/subtitles/#{id}")
    end

    # Finished segments, or nil while recognition is still running.
    #
    # Deliberately not gated on #status: the API leaves audio_extraction_progress
    # short of 100 on completed jobs, so status can sit at "processing" while the
    # transcript is ready. A 409 is the only reliable "not yet".
    def transcript(id)
      response = HTTParty.get("#{BASE_URL}/subtitles/#{id}/transcript", headers:)
      return if response.code == 409

      handle_errors(response)
      response.parsed_response["transcript"]
    end

    # Key tier, status and remaining daily quota - useful when a submission
    # starts failing and you need to know whether the key is the problem.
    def key_status
      request(:get, "/apikey/status")
    end

    private

    def request(method, path, **options)
      response = HTTParty.public_send(method, "#{BASE_URL}#{path}", headers:, **options)
      handle_errors(response)
      response.parsed_response
    end

    def handle_errors(response)
      return if response.success?

      message = response.parsed_response.try(:[], "message") || response.body
      raise Error, "Abair API #{response.code}: #{message}"
    end

    def headers
      raise Error, "No Abair API key configured" if @api_key.blank?

      {"abair-api-key" => @api_key}
    end
  end
end
