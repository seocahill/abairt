require "test_helper"

class QuestionRouterTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:whatsapp_speaker)
    @asker = users(:two)
    Question.delete_all
  end

  def question(status, speaker: @speaker)
    record = Question.new(asker: @asker, speaker: speaker)
    record.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    record.save!
    record.update!(status: status)
    record
  end

  test "finds a speaker who has no questions at all" do
    assert_equal @speaker, QuestionRouter.new.speaker
  end

  # These two were a real bug: filtering on the left-joined questions table
  # dropped the speaker entirely once none of their rows matched, so the first
  # answered question made every later question unroutable.
  test "still finds a speaker whose questions are all answered" do
    question(:answered)

    assert_equal @speaker, QuestionRouter.new.speaker
  end

  test "still finds a speaker holding only an unsent draft" do
    question(:draft)

    assert_equal @speaker, QuestionRouter.new.speaker
  end

  test "prefers the speaker with the shorter unanswered backlog" do
    other = User.create!(name: "Nóra", confirmed: true, role: :speaker,
      phone_number: "353869999999", answers_questions: true)
    question(:waiting)
    question(:waiting)
    question(:waiting, speaker: other)

    assert_equal other, QuestionRouter.new.speaker
  end

  test "answered and draft questions do not count against a speaker" do
    other = User.create!(name: "Nóra", confirmed: true, role: :speaker,
      phone_number: "353869999999", answers_questions: true)
    3.times { question(:answered) }
    question(:draft)
    question(:waiting, speaker: other)

    # @speaker has four questions but none of them outstanding.
    assert_equal @speaker, QuestionRouter.new.speaker
  end

  test "returns nothing when nobody is taking questions" do
    @speaker.update!(answers_questions: false)

    assert_nil QuestionRouter.new.speaker
  end
end
