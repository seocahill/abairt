require "test_helper"

# The Telegram half of the shared ProcessInbound. The WhatsApp half is in
# test/services/process_inbound_test.rb and exercises the same class — the point
# of these is that the behaviour is identical on a transport with no 24 hour
# window, no templates and a different idea of who a sender is.
class Telegram::ProcessInboundTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:telegram_speaker)
    @speaker.update!(answers_questions: true)
    Question.delete_all
  end

  def inbound(overrides = {})
    Telegram::InboundMessage.new({
      "message_id" => 42,
      "from" => {"id" => 99887766},
      "chat" => {"id" => 99887766},
      "voice" => {"file_id" => "file-abc", "mime_type" => "audio/ogg"}
    }.merge(overrides))
  end

  def create_question(status: :waiting)
    question = Question.new(asker: users(:two), speaker: @speaker, status: status)
    question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )
    question.save!
    question
  end

  test "a voice note answers the question the speaker is holding" do
    question = create_question(status: :sent)
    Telegram::Client.any_instance.stubs(:download_file).returns("ogg-bytes")
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns(nil)

    ProcessInbound.new(inbound).call

    question.reload
    assert question.answered?
    assert question.answer_audio.attached?
    assert_equal "telegram:99887766:42", question.answer_message_id
  end

  test "answering releases the next question in the queue" do
    answered = create_question(status: :sent)
    waiting = create_question
    Telegram::Client.any_instance.stubs(:download_file).returns("ogg-bytes")
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:99887766:43")

    ProcessInbound.new(inbound).call

    assert answered.reload.answered?
    assert waiting.reload.sent?
  end

  test "a hello with nothing outstanding sends what is waiting" do
    waiting = create_question
    Telegram::Client.any_instance.expects(:download_file).never
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:99887766:43")

    ProcessInbound.new(Telegram::InboundMessage.new({
      "message_id" => 43,
      "from" => {"id" => 99887766},
      "chat" => {"id" => 99887766},
      "text" => "Dia dhuit"
    })).call

    assert waiting.reload.sent?
  end

  test "a redelivered update does not answer twice" do
    question = create_question(status: :sent)
    Telegram::Client.any_instance.stubs(:download_file).returns("ogg-bytes")
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns(nil)

    2.times { ProcessInbound.new(inbound).call }

    assert_equal 1, question.reload.answer_audio.attachments.size
  end

  test "a stranger is asked for their number rather than ignored" do
    Telegram::Client.any_instance.expects(:request_contact).once
    Telegram::DeliverQuestion.any_instance.expects(:call).never

    ProcessInbound.new(inbound("chat" => {"id" => 5}, "from" => {"id" => 5})).call
  end

  test "sharing a number claims the chat and the queue starts flowing" do
    @speaker.update!(telegram_chat_id: nil)
    waiting = create_question
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:5:1")

    ProcessInbound.new(Telegram::InboundMessage.new({
      "message_id" => 1,
      "from" => {"id" => 5},
      "chat" => {"id" => 5},
      "contact" => {"phone_number" => "353871112222", "user_id" => 5}
    })).call

    assert_equal "5", @speaker.reload.telegram_chat_id
    assert waiting.reload.sent?
  end
end
