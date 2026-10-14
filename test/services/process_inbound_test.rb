require "test_helper"

# The WhatsApp half of the shared ProcessInbound. Telegram's is in
# test/services/telegram/process_inbound_test.rb and exercises the same class.
class ProcessInboundTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:whatsapp_speaker)
    Question.delete_all
  end

  def inbound(attributes)
    Whatsapp::InboundMessage.new({
      "id" => "wamid.abc",
      "from" => @speaker.phone_number,
      "type" => "audio",
      "audio" => {"id" => "media-123"}
    }.merge(attributes))
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
    Whatsapp::Client.any_instance.stubs(:download_media).returns("ogg-bytes")
    Whatsapp::DeliverQuestion.any_instance.stubs(:call).returns(nil)

    ProcessInbound.new(inbound({})).call

    question.reload
    assert question.answered?
    assert question.answer_audio.attached?
    assert_equal "whatsapp:wamid.abc", question.answer_message_id
  end

  test "answering releases the next question in the queue" do
    create_question(status: :sent)
    waiting = create_question
    Whatsapp::Client.any_instance.stubs(:download_media).returns("ogg-bytes")
    Whatsapp::DeliverQuestion.any_instance.stubs(:call).returns("wamid.next")

    ProcessInbound.new(inbound({})).call

    assert waiting.reload.sent?
  end

  test "any message reopens the window and releases what is waiting" do
    @speaker.update!(whatsapp_last_inbound_at: 3.days.ago)
    waiting = create_question
    Whatsapp::DeliverQuestion.any_instance.stubs(:call).returns("wamid.next")

    ProcessInbound.new(inbound("type" => "button", "button" => {"text" => "Tá mé réidh"})).call

    assert @speaker.reload.whatsapp_window_open?
    assert waiting.reload.sent?
  end

  test "a voice note with nothing outstanding is not treated as an answer" do
    waiting = create_question
    Whatsapp::Client.any_instance.expects(:download_media).never
    Whatsapp::DeliverQuestion.any_instance.stubs(:call).returns("wamid.next")

    ProcessInbound.new(inbound({})).call

    assert waiting.reload.sent?
  end

  test "ignores a message from a number we do not know" do
    Whatsapp::DeliverQuestion.any_instance.expects(:call).never

    assert_nothing_raised do
      ProcessInbound.new(inbound("from" => "353869999999")).call
    end
  end

  test "a redelivered webhook does not answer twice" do
    question = create_question(status: :sent)
    Whatsapp::Client.any_instance.stubs(:download_media).returns("ogg-bytes")
    Whatsapp::DeliverQuestion.any_instance.stubs(:call).returns(nil)

    2.times { ProcessInbound.new(inbound({})).call }

    assert_equal 1, question.reload.answer_audio.attachments.size
  end
end
