require "test_helper"

class Telegram::DeliverQuestionTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:speaker)
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

    assert_equal "telegram:11223344:42", Telegram::DeliverQuestion.new(@question, client: @client).call
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
