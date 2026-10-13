require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  def setup
    @asker = users(:two)
    @speaker = users(:whatsapp_speaker)
  end

  def build_question(attributes = {})
    question = Question.new({asker: @asker, speaker: @speaker}.merge(attributes))
    question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )
    question
  end

  test "is valid with audio, an asker and a speaker who takes questions" do
    assert build_question.valid?
  end

  test "requires audio" do
    question = Question.new(asker: @asker, speaker: @speaker)

    assert_not question.valid?
    assert_includes question.errors[:audio], "can't be blank"
  end

  test "will not route to a speaker who is not taking questions" do
    question = build_question(speaker: users(:three))

    assert_not question.valid?
    assert_includes question.errors[:speaker], "is not taking questions"
  end

  test "starts out a draft, not queued" do
    assert build_question.draft?
  end

  test "send_to_speaker! moves a draft into the queue" do
    question = build_question
    question.save!

    assert question.send_to_speaker!
    assert question.waiting?
  end

  test "send_to_speaker! refuses anything that is not a draft" do
    question = build_question
    question.save!
    question.send_to_speaker!

    # A second tap, or a replayed request, must not re-queue it.
    assert_not question.send_to_speaker!
    assert question.waiting?
  end

  test "mark_sent! records the whatsapp message id" do
    question = build_question
    question.save!

    question.mark_sent!("wamid.abc")

    assert question.sent?
    assert_equal "wamid.abc", question.wa_question_message_id
    assert_not_nil question.sent_at
  end
end
