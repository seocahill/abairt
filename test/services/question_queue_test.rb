require "test_helper"

class QuestionQueueTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:speaker)
    @queue = QuestionQueue.new(@speaker)
    Question.delete_all
  end

  def create_question(asker: users(:two), created_at: Time.current, speaker: @speaker)
    question = Question.new(asker: asker, speaker: speaker, created_at: created_at)
    question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )
    question.save!
    # The queue only ever sees questions the learner has actually sent.
    question.send_to_speaker!
    question
  end

  # A question recorded before anybody was connected has no speaker. It is not
  # stranded: the first speaker to come free claims it on the way out, which is
  # what lets a learner record now and a speaker arrive later.
  test "claims a question that was waiting for nobody in particular" do
    orphan = create_question(speaker: nil)
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:11223344:1")

    delivered = @queue.deliver_next

    assert_equal orphan, delivered
    assert_equal @speaker, orphan.reload.speaker
    assert orphan.sent?
  end

  test "an unassigned question and one of its own queue up oldest first" do
    mine = create_question(created_at: 1.minute.ago)
    orphan = create_question(created_at: 1.hour.ago, speaker: nil)
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:11223344:1")

    assert_equal orphan, @queue.deliver_next
    assert mine.reload.waiting?
  end

  test "delivers the oldest waiting question" do
    newer = create_question(created_at: 1.minute.ago)
    older = create_question(created_at: 1.hour.ago)
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:11223344:1")

    delivered = @queue.deliver_next

    assert_equal older, delivered
    assert older.reload.sent?
    assert newer.reload.waiting?
  end

  test "sends nothing while the speaker is still holding one" do
    create_question(created_at: 1.hour.ago).mark_sent!("wamid.first")
    create_question(created_at: 1.minute.ago)
    Telegram::DeliverQuestion.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  test "does nothing when there is nothing waiting" do
    Telegram::DeliverQuestion.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  test "leaves the question waiting when delivery did not happen" do
    question = create_question
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns(nil)

    @queue.deliver_next

    assert question.reload.waiting?
  end

  test "ignores drafts the learner has not sent" do
    draft = Question.new(asker: users(:two), speaker: @speaker)
    draft.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3",
      content_type: "audio/mpeg"
    )
    draft.save!
    Telegram::DeliverQuestion.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
    assert draft.reload.draft?
  end

  test "outstanding returns the question the speaker is holding" do
    question = create_question
    question.mark_sent!("telegram:11223344:1")

    assert_equal question, @queue.outstanding
  end
end
