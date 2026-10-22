require "test_helper"

class Telegram::ProcessInboundTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:speaker)
    @speaker.update!(answers_questions: true)
    Question.delete_all
    SegmentPrompt.delete_all
  end

  def text_message(body)
    Telegram::InboundMessage.new({
      "message_id" => 77,
      "from" => {"id" => 11223344},
      "chat" => {"id" => 11223344},
      "text" => body
    })
  end

  def sent_prompt
    SegmentPrompt.create!(
      dictionary_entry: dictionary_entries(:one),
      speaker: @speaker,
      sent_at: Time.current
    )
  end

  def inbound(overrides = {})
    Telegram::InboundMessage.new({
      "message_id" => 42,
      "from" => {"id" => 11223344},
      "chat" => {"id" => 11223344},
      "voice" => {"file_id" => "file-abc", "mime_type" => "audio/ogg"}
    }.merge(overrides))
  end

  def create_question(status: :waiting, speaker: @speaker)
    question = Question.new(asker: users(:two), speaker: speaker, status: status)
    question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )
    question.save!
    question
  end

  # The promise the asking screen makes: record with nobody connected and the
  # question goes out the moment somebody arrives. Nothing in the Telegram path
  # had to learn about it — onboarding already ran the queue, and the queue now
  # claims a question that is waiting for nobody in particular.
  test "a speaker following an invite link picks up a question that was waiting for nobody" do
    @speaker.update!(telegram_chat_id: nil)
    @speaker.regenerate_telegram_invite_token
    orphan = create_question(status: :waiting, speaker: nil)

    Telegram::Client.any_instance.stubs(:send_text)
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:11223344:7")

    ProcessInbound.new(Telegram::InboundMessage.new({
      "message_id" => 7,
      "from" => {"id" => 11223344},
      "chat" => {"id" => 11223344},
      "text" => "/start #{@speaker.telegram_invite_token}"
    })).call

    orphan.reload
    assert_equal @speaker, orphan.speaker
    assert orphan.sent?
  end

  # Holding a segment rather than a question, the same voice note means
  # something else entirely — and nothing had to be tagged for us to know.
  test "a voice note against a segment is a correction, not an answer" do
    prompt = sent_prompt
    Telegram::Client.any_instance.stubs(:download_file).returns("ogg-bytes")

    ProcessInbound.new(inbound).call

    prompt.reload
    assert prompt.corrected?
    assert prompt.correction_audio.attached?
    # Deliberately not confirmed: somebody still has to write it down.
    assert dictionary_entries(:one).reload.unconfirmed?
  end

  test "the button says the transcription was already right" do
    prompt = sent_prompt

    ProcessInbound.new(text_message(Telegram::DeliverSegment::CONFIRM)).call

    assert prompt.reload.confirmed?
    assert dictionary_entries(:one).reload.confirmed?
  end

  test "anything else leaves the segment out with them" do
    prompt = sent_prompt

    ProcessInbound.new(text_message("Dia dhuit")).call

    assert prompt.reload.sent?
  end

  test "a voice note answers the question the speaker is holding" do
    question = create_question(status: :sent)
    Telegram::Client.any_instance.stubs(:download_file).returns("ogg-bytes")
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns(nil)

    ProcessInbound.new(inbound).call

    question.reload
    assert question.answered?
    assert question.answer_audio.attached?
    assert_equal "telegram:11223344:42", question.answer_message_id
    assert_equal "audio/ogg", question.answer_audio.content_type
  end

  test "answering releases the next question in the queue" do
    answered = create_question(status: :sent)
    waiting = create_question
    Telegram::Client.any_instance.stubs(:download_file).returns("ogg-bytes")
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:11223344:43")

    ProcessInbound.new(inbound).call

    assert answered.reload.answered?
    assert waiting.reload.sent?
  end

  test "a hello with nothing outstanding sends what is waiting" do
    waiting = create_question
    Telegram::Client.any_instance.expects(:download_file).never
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:11223344:43")

    ProcessInbound.new(Telegram::InboundMessage.new({
      "message_id" => 43,
      "from" => {"id" => 11223344},
      "chat" => {"id" => 11223344},
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
      "contact" => {"phone_number" => "353861234567", "user_id" => 5}
    })).call

    assert_equal "5", @speaker.reload.telegram_chat_id
    assert waiting.reload.sent?
  end
end
