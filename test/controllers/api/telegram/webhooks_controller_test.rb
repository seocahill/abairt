require "test_helper"

class Api::Telegram::WebhooksControllerTest < ActionDispatch::IntegrationTest
  SECRET = "test_webhook_secret"

  def setup
    ENV["TELEGRAM_WEBHOOK_SECRET"] = SECRET
  end

  def teardown
    ENV.delete("TELEGRAM_WEBHOOK_SECRET")
  end

  def headers(secret = SECRET)
    {"X-Telegram-Bot-Api-Secret-Token" => secret, "CONTENT_TYPE" => "application/json"}
  end

  def payload
    {
      "update_id" => 1,
      "message" => {
        "message_id" => 42,
        "from" => {"id" => 99887766},
        "chat" => {"id" => 99887766},
        "voice" => {"file_id" => "file-abc", "mime_type" => "audio/ogg"}
      }
    }
  end

  test "queues an update carrying the right secret" do
    assert_enqueued_with(job: ProcessTelegramMessageJob) do
      post "/api/telegram/webhook", params: payload.to_json, headers: headers
    end

    assert_response :success
  end

  test "rejects an update carrying the wrong secret" do
    assert_no_enqueued_jobs only: ProcessTelegramMessageJob do
      post "/api/telegram/webhook", params: payload.to_json, headers: headers("wrong")
    end

    assert_response :unauthorized
  end

  test "rejects an update carrying no secret at all" do
    assert_no_enqueued_jobs only: ProcessTelegramMessageJob do
      post "/api/telegram/webhook", params: payload.to_json,
        headers: {"CONTENT_TYPE" => "application/json"}
    end

    assert_response :unauthorized
  end

  # Without this, anyone who guessed the URL could post updates on a deployment
  # that had simply forgotten to configure the secret.
  test "rejects everything when no secret is configured" do
    ENV.delete("TELEGRAM_WEBHOOK_SECRET")

    assert_no_enqueued_jobs only: ProcessTelegramMessageJob do
      post "/api/telegram/webhook", params: payload.to_json, headers: headers
    end

    assert_response :unauthorized
  end
end
