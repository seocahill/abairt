require "test_helper"

class Api::Whatsapp::WebhooksControllerTest < ActionDispatch::IntegrationTest
  APP_SECRET = "test_app_secret"
  VERIFY_TOKEN = "test_verify_token"

  def setup
    ENV["WHATSAPP_APP_SECRET"] = APP_SECRET
    ENV["WHATSAPP_VERIFY_TOKEN"] = VERIFY_TOKEN
  end

  def teardown
    ENV.delete("WHATSAPP_APP_SECRET")
    ENV.delete("WHATSAPP_VERIFY_TOKEN")
  end

  def signed_headers(body)
    signature = OpenSSL::HMAC.hexdigest("SHA256", APP_SECRET, body)
    {"X-Hub-Signature-256" => "sha256=#{signature}", "CONTENT_TYPE" => "application/json"}
  end

  def payload
    {
      "object" => "whatsapp_business_account",
      "entry" => [{"changes" => [{"value" => {"messages" => [
        {"id" => "wamid.abc", "from" => "353861234567", "type" => "audio",
         "audio" => {"id" => "media-1"}}
      ]}}]}]
    }
  end

  test "answers Meta's subscription handshake with the challenge" do
    get "/api/whatsapp/webhook", params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => VERIFY_TOKEN,
      "hub.challenge" => "12345"
    }

    assert_response :success
    assert_equal "12345", response.body
  end

  test "refuses a handshake with the wrong verify token" do
    get "/api/whatsapp/webhook", params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "wrong",
      "hub.challenge" => "12345"
    }

    assert_response :forbidden
  end

  test "queues a correctly signed message" do
    body = payload.to_json

    assert_enqueued_with(job: ProcessWhatsappMessageJob) do
      post "/api/whatsapp/webhook", params: body, headers: signed_headers(body)
    end

    assert_response :success
  end

  test "rejects a message with a bad signature" do
    body = payload.to_json

    assert_no_enqueued_jobs only: ProcessWhatsappMessageJob do
      post "/api/whatsapp/webhook", params: body,
        headers: {"X-Hub-Signature-256" => "sha256=deadbeef", "CONTENT_TYPE" => "application/json"}
    end

    assert_response :unauthorized
  end

  test "rejects a message with no signature at all" do
    post "/api/whatsapp/webhook", params: payload.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :unauthorized
  end
end
