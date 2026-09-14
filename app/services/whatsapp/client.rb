# frozen_string_literal: true

module Whatsapp
  # Thin wrapper over the WhatsApp Cloud API (Meta Graph).
  #
  # Only the four calls this app makes: upload a voice note, send it, send the
  # nudge template, and download what comes back.
  #
  #   Whatsapp::Client.new.send_audio(to: "353861234567", media_id: id)
  class Client
    include HTTParty

    BASE_URL = "https://graph.facebook.com"

    class Error < StandardError; end

    def initialize
      @access_token = credential(:access_token, "WHATSAPP_ACCESS_TOKEN")
      @phone_number_id = credential(:phone_number_id, "WHATSAPP_PHONE_NUMBER_ID")
      @api_version = credential(:api_version, "WHATSAPP_API_VERSION") || "v23.0"
    end

    # Uploads a voice note and returns Meta's media id.
    #
    # WhatsApp only renders ogg/opus as a playable voice bubble — anything else
    # arrives as a file attachment, which is not something to hand an elderly
    # user. Whatever calls this is responsible for the transcode.
    def upload_media(path, content_type: "audio/ogg")
      response = self.class.post(
        "#{base}/#{@phone_number_id}/media",
        headers: {"Authorization" => "Bearer #{@access_token}"},
        body: {
          messaging_product: "whatsapp",
          type: content_type,
          file: File.open(path)
        },
        multipart: true
      )

      parse(response, "upload media").fetch("id")
    end

    def send_audio(to:, media_id:)
      send_message(to: to, type: "audio", payload: {audio: {id: media_id}})
    end

    def send_text(to:, body:)
      send_message(to: to, type: "text", payload: {text: {body: body, preview_url: false}})
    end

    # Templates are the only thing we may send outside the 24 hour window, and
    # they cannot carry audio — so this is a nudge with a button, not content.
    def send_template(to:, name:, language: "ga")
      send_message(
        to: to,
        type: "template",
        payload: {template: {name: name, language: {code: language}}}
      )
    end

    # Two hops: the media id resolves to a short-lived URL, which needs the same
    # bearer token to fetch. Returns the raw bytes.
    def download_media(media_id)
      lookup = self.class.get(
        "#{base}/#{media_id}",
        headers: {"Authorization" => "Bearer #{@access_token}"}
      )

      url = parse(lookup, "look up media").fetch("url")

      response = self.class.get(url, headers: {"Authorization" => "Bearer #{@access_token}"})
      raise Error, "Failed to download media #{media_id}: #{response.code}" unless response.success?

      response.body
    end

    def configured?
      @access_token.present? && @phone_number_id.present?
    end

    private

    def send_message(to:, type:, payload:)
      response = self.class.post(
        "#{base}/#{@phone_number_id}/messages",
        headers: {
          "Authorization" => "Bearer #{@access_token}",
          "Content-Type" => "application/json"
        },
        body: {
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: to,
          type: type
        }.merge(payload).to_json
      )

      parse(response, "send #{type}").dig("messages", 0, "id")
    end

    def parse(response, action)
      body = JSON.parse(response.body.to_s)
      return body if response.success?

      raise Error, "Failed to #{action}: #{response.code} #{body.dig("error", "message")}"
    rescue JSON::ParserError
      raise Error, "Failed to #{action}: #{response.code} (unparseable response)"
    end

    def base
      "#{BASE_URL}/#{@api_version}"
    end

    def credential(key, env_key)
      Rails.application.credentials.dig(:whatsapp, key) || ENV[env_key]
    end
  end
end
