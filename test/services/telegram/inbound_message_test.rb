require "test_helper"

class Telegram::InboundMessageTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:telegram_speaker)
    @speaker.update!(answers_questions: true)
    @client = mock("client")
  end

  def update(message)
    {"update_id" => 1, "message" => message}
  end

  def voice_note(overrides = {})
    {
      "message_id" => 42,
      "from" => {"id" => 99887766},
      "chat" => {"id" => 99887766},
      "voice" => {"file_id" => "file-abc", "mime_type" => "audio/ogg"}
    }.merge(overrides)
  end

  test "pulls the message out of the update" do
    messages = Telegram::InboundMessage.from_payload(update(voice_note))

    assert_equal 1, messages.size
    assert messages.first.audio?
  end

  test "ignores an update carrying no message" do
    assert_empty Telegram::InboundMessage.from_payload({"update_id" => 1, "edited_message" => voice_note})
  end

  # A Telegram message id is only unique within its chat, and both transports'
  # ids land in the same uniquely-indexed column.
  test "namespaces the message id by chat" do
    message = Telegram::InboundMessage.new(voice_note, client: @client)

    assert_equal "telegram:99887766:42", message.id
  end

  test "finds the speaker by chat id" do
    message = Telegram::InboundMessage.new(voice_note, client: @client)

    assert_equal @speaker, message.speaker
  end

  test "does not find a speaker who is not taking questions" do
    @speaker.update!(answers_questions: false)
    message = Telegram::InboundMessage.new(voice_note, client: @client)

    assert_nil message.speaker
  end

  test "does not mistake a WhatsApp speaker for a Telegram one" do
    @speaker.update!(telegram_chat_id: nil)
    users(:whatsapp_speaker).update!(telegram_chat_id: "99887766")
    message = Telegram::InboundMessage.new(voice_note, client: @client)

    assert_nil message.speaker
  end

  test "asks an unknown chat for its number" do
    @client.expects(:request_contact).with(
      chat_id: "123123",
      text: Telegram::InboundMessage::GREETING,
      button: Telegram::InboundMessage::SHARE_BUTTON
    )
    message = Telegram::InboundMessage.new(
      voice_note("chat" => {"id" => 123123}, "from" => {"id" => 123123}), client: @client
    )

    assert_nil message.onboard
  end

  test "a shared number claims the speaker expecting it" do
    @speaker.update!(telegram_chat_id: nil)
    message = Telegram::InboundMessage.new({
      "message_id" => 2,
      "from" => {"id" => 555},
      "chat" => {"id" => 555},
      "contact" => {"phone_number" => "+353 87 111 2222", "user_id" => 555}
    }, client: @client)

    assert_equal @speaker, message.onboard
    assert_equal "555", @speaker.reload.telegram_chat_id
  end

  # A contact card can be forwarded from an address book, so it is only evidence
  # about the sender when it describes the sender.
  test "a contact card for somebody else claims nothing" do
    @speaker.update!(telegram_chat_id: nil)
    message = Telegram::InboundMessage.new({
      "message_id" => 2,
      "from" => {"id" => 555},
      "chat" => {"id" => 555},
      "contact" => {"phone_number" => "353871112222", "user_id" => 999}
    }, client: @client)

    assert_nil message.onboard
    assert_nil @speaker.reload.telegram_chat_id
  end

  test "a shared number nobody is expecting claims nothing" do
    message = Telegram::InboundMessage.new({
      "message_id" => 2,
      "from" => {"id" => 555},
      "chat" => {"id" => 555},
      "contact" => {"phone_number" => "353860000000", "user_id" => 555}
    }, client: @client)

    assert_nil message.onboard
  end

  test "downloads the voice note it was sent" do
    @client.expects(:download_file).with("file-abc").returns("ogg-bytes")
    message = Telegram::InboundMessage.new(voice_note, client: @client)

    assert_equal "ogg-bytes", message.download_audio
  end
end
