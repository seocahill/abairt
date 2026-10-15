# frozen_string_literal: true

module Telegram
  # Thin wrapper over the Telegram Bot API.
  #
  # Only the calls this app makes: send a voice note, send a line of text, ask
  # for a phone number, and fetch what comes back.
  #
  #   Telegram::Client.new.send_voice(chat_id: "123", path: "/tmp/q.ogg")
  #
  # Every response is `{"ok": true, "result": ...}` or `{"ok": false,
  # "description": "..."}`, and an HTTP error carries the same body, so `ok` is
  # the only thing worth checking.
  class Client
    include HTTParty

    BASE_URL = "https://api.telegram.org"

    class Error < TransportError; end

    def initialize
      @token = credential(:bot_token, "TELEGRAM_BOT_TOKEN")
    end

    # Returns Telegram's message id. sendVoice is the one that renders as a
    # playable voice bubble rather than a file; it wants ogg/opus, which
    # OpusVoiceNote guarantees.
    def send_voice(chat_id:, path:)
      File.open(path) do |file|
        result = post("sendVoice", {chat_id: chat_id, voice: file}, multipart: true)
        result.fetch("message_id")
      end
    end

    def send_text(chat_id:, text:)
      result = post("sendMessage", {chat_id: chat_id, text: text})
      result.fetch("message_id")
    end

    # One button that shares the sender's phone number, which is how a speaker's
    # chat is matched to the record we already hold for them. Telegram vouches
    # for the number, so this is better evidence than anything they could type.
    def request_contact(chat_id:, text:, button:)
      post("sendMessage", {
        chat_id: chat_id,
        text: text,
        reply_markup: {
          keyboard: [[{text: button, request_contact: true}]],
          resize_keyboard: true,
          one_time_keyboard: true
        }.to_json
      })
    end

    # Long polling, for local development: no public URL and no tunnel. `offset`
    # is the id after the last update already handled — Telegram keeps an update
    # on the queue until an offset past it is acknowledged, so this is also what
    # stops the same message arriving for ever.
    #
    # Mutually exclusive with a webhook. Telegram answers 409 if one is set,
    # which the poller reports rather than deleting it: that webhook may be
    # production's.
    def get_updates(offset: nil, timeout: 30)
      body = {timeout: timeout}
      body[:offset] = offset if offset

      response = self.class.post(
        "#{BASE_URL}/bot#{@token}/getUpdates",
        body: body,
        timeout: timeout + 10
      )
      parse(response, "getUpdates")
    end

    # Two hops, as with WhatsApp: the file id resolves to a path, which is
    # fetched from a different host. Returns the raw bytes.
    def download_file(file_id)
      path = post("getFile", {file_id: file_id}).fetch("file_path")

      response = self.class.get("#{BASE_URL}/file/bot#{@token}/#{path}")
      raise Error, "Failed to download file #{file_id}: #{response.code}" unless response.success?

      response.body
    end

    def configured?
      @token.present?
    end

    private

    def post(method, body, multipart: false)
      response = self.class.post("#{BASE_URL}/bot#{@token}/#{method}", body: body, multipart: multipart)
      parse(response, method)
    end

    def parse(response, method)
      body = JSON.parse(response.body.to_s)
      return body.fetch("result") if body["ok"]

      raise Error, "Telegram #{method} failed: #{response.code} #{body["description"]}"
    rescue JSON::ParserError
      raise Error, "Telegram #{method} failed: #{response.code} (unparseable response)"
    end

    def credential(key, env_key)
      Rails.application.credentials.dig(:telegram, key) || ENV[env_key]
    end
  end
end
