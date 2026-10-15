require "test_helper"

class QuestionTransportTest < ActiveSupport::TestCase
  def setup
    Question.delete_all
  end

  def question_for(speaker)
    question = Question.new(asker: users(:two), speaker: speaker)
    question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )
    question.save!
    question
  end

  test "carries a WhatsApp speaker's question over WhatsApp" do
    adapter = QuestionTransport.for(question_for(users(:whatsapp_speaker)))

    assert_instance_of Whatsapp::DeliverQuestion, adapter
  end

  test "carries a Telegram speaker's question over Telegram" do
    speaker = users(:telegram_speaker)
    speaker.update!(answers_questions: true)

    adapter = QuestionTransport.for(question_for(speaker))

    assert_instance_of Telegram::DeliverQuestion, adapter
  end

  # One speaker on each transport at the same time, which is the whole point of
  # the channel living on the speaker rather than in the code.
  test "two speakers on different transports are routed separately" do
    telegram = users(:telegram_speaker)
    telegram.update!(answers_questions: true)

    assert_instance_of Whatsapp::DeliverQuestion, QuestionTransport.for(question_for(users(:whatsapp_speaker)))
    assert_instance_of Telegram::DeliverQuestion, QuestionTransport.for(question_for(telegram))
  end
end
