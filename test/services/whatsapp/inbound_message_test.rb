require "test_helper"

class Whatsapp::InboundMessageTest < ActiveSupport::TestCase
  def payload(message)
    {
      "object" => "whatsapp_business_account",
      "entry" => [
        {"changes" => [{"value" => {"messages" => [message]}, "field" => "messages"}]}
      ]
    }
  end

  test "pulls an audio message out of the envelope" do
    messages = Whatsapp::InboundMessage.from_payload(payload(
      "id" => "wamid.abc",
      "from" => "353861234567",
      "type" => "audio",
      "audio" => {"id" => "media-123", "voice" => true}
    ))

    assert_equal 1, messages.size
    message = messages.first
    assert message.audio?
    assert_equal "whatsapp:wamid.abc", message.id
    assert_equal "353861234567", message.from
    assert_equal "media-123", message.audio_media_id
  end

  test "recognises a quick reply button tap" do
    message = Whatsapp::InboundMessage.from_payload(payload(
      "id" => "wamid.btn", "from" => "353861234567", "type" => "button",
      "button" => {"text" => "Tá mé réidh"}
    )).first

    assert message.button?
    assert_not message.audio?
  end

  test "ignores delivery receipts, which carry no messages" do
    statuses = {
      "entry" => [{"changes" => [{"value" => {"statuses" => [{"status" => "read"}]}}]}]
    }

    assert_empty Whatsapp::InboundMessage.from_payload(statuses)
  end

  test "handles an empty payload" do
    assert_empty Whatsapp::InboundMessage.from_payload({})
  end
end
