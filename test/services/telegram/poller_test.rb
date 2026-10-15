require "test_helper"

class Telegram::PollerTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:telegram_speaker)
    @speaker.update!(answers_questions: true)
    Question.delete_all
    @client = mock("client")
  end

  def update(id, message)
    {"update_id" => id, "message" => message}
  end

  def voice_note
    {
      "message_id" => 42,
      "from" => {"id" => 99887766},
      "chat" => {"id" => 99887766},
      "voice" => {"file_id" => "file-abc", "mime_type" => "audio/ogg"}
    }
  end

  def create_question(status: :sent)
    question = Question.new(asker: users(:two), speaker: @speaker, status: status)
    question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )
    question.save!
    question
  end

  # The whole point: a polled update goes through the same path a webhook
  # delivery does, so what works locally works deployed.
  test "handles a polled update exactly as the webhook would" do
    question = create_question
    Telegram::Client.any_instance.stubs(:download_file).returns("ogg-bytes")
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns(nil)
    @client.expects(:get_updates).with(offset: nil).returns([update(1, voice_note)])

    assert_equal 1, Telegram::Poller.new(client: @client).poll
    assert question.reload.answered?
  end

  # Telegram keeps an update queued until an offset past it is acknowledged.
  test "acknowledges what it has seen so the same update does not come back" do
    poller = Telegram::Poller.new(client: @client)
    @client.expects(:get_updates).with(offset: nil).returns([update(7, {"message_id" => 1, "chat" => {"id" => 5}, "from" => {"id" => 5}, "text" => "hi"})])
    Telegram::Client.any_instance.stubs(:request_contact)

    poller.poll

    @client.expects(:get_updates).with(offset: 8).returns([])
    poller.poll
  end

  test "an update that blows up is still acknowledged" do
    poller = Telegram::Poller.new(client: @client, logger: Logger.new(File::NULL))
    @client.expects(:get_updates).with(offset: nil).returns([update(3, voice_note)])
    Telegram::Client.any_instance.stubs(:download_file).raises(Telegram::Client::Error, "boom")
    create_question

    assert_nothing_raised { poller.poll }

    @client.expects(:get_updates).with(offset: 4).returns([])
    poller.poll
  end

  # Deleting the webhook here could take production offline.
  test "refuses to poll past a webhook rather than deleting it" do
    @client.expects(:get_updates).raises(Telegram::Client::Error,
      "Telegram getUpdates failed: 409 Conflict: can't use getUpdates method while webhook is active")

    error = assert_raises(Telegram::Poller::WebhookInTheWay) do
      Telegram::Poller.new(client: @client).poll
    end
    assert_match(/webhook is set/, error.message)
  end

  # Telegram answers 409 to both, and says which. Reporting a second poller as
  # a webhook sends you looking at production for a stray terminal.
  test "tells a second poller apart from a webhook" do
    @client.expects(:get_updates).raises(Telegram::Client::Error,
      "Telegram getUpdates failed: 409 Conflict: terminated by other getUpdates request; " \
      "make sure that only one bot instance is running")

    error = assert_raises(Telegram::Poller::AlreadyPolling) do
      Telegram::Poller.new(client: @client).poll
    end
    assert_match(/Another poller/, error.message)
  end

  test "both conflicts share a parent the rake task can rescue" do
    assert_operator Telegram::Poller::WebhookInTheWay, :<, Telegram::Poller::Conflict
    assert_operator Telegram::Poller::AlreadyPolling, :<, Telegram::Poller::Conflict
  end

  test "lets any other client error through" do
    @client.expects(:get_updates).raises(Telegram::Client::Error, "401 Unauthorized")

    assert_raises(Telegram::Client::Error) { Telegram::Poller.new(client: @client).poll }
  end

  test "run(once: true) polls a single time" do
    @client.expects(:get_updates).once.returns([])

    Telegram::Poller.new(client: @client).run(once: true)
  end
end
