require "test_helper"

class Telegram::DeliverQuestionTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:telegram_speaker)
    @speaker.update!(answers_questions: true)
    Question.delete_all
    @question = Question.new(asker: users(:two), speaker: @speaker)
    @question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.ogg",
      content_type: "audio/ogg",
      identify: false
    )
    @question.save!
    @client = mock("client")
  end

  test "sends the voice note and returns a namespaced message id" do
    @client.expects(:send_voice).with { |chat_id:, path:|
      chat_id == @speaker.telegram_chat_id && File.exist?(path)
    }.returns(42)

    assert_equal "telegram:99887766:42", Telegram::DeliverQuestion.new(@question, client: @client).call
  end

  # No window to be shut, so unlike WhatsApp there is no second path here at
  # all: holding a chat id is enough, however long ago it was last used.
  test "sends however long it has been since the speaker last wrote" do
    @speaker.update!(whatsapp_last_inbound_at: 3.years.ago)
    @client.expects(:send_voice).returns(7)

    assert_equal "telegram:99887766:7", Telegram::DeliverQuestion.new(@question, client: @client).call
  end

  test "leaves the question waiting when Telegram refuses it" do
    @client.expects(:send_voice).raises(Telegram::Client::Error, "Bad Request: chat not found")

    assert_nil Telegram::DeliverQuestion.new(@question, client: @client).call
    assert @question.reload.draft?
  end

  test "leaves the question waiting when the audio cannot be transcoded" do
    OpusVoiceNote.any_instance.stubs(:open).raises(OpusVoiceNote::TranscodeError, "no opus")

    assert_nil Telegram::DeliverQuestion.new(@question, client: @client).call
  end
end
