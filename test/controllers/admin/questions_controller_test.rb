require "test_helper"

class Admin::QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @speaker = users(:speaker)
    ApplicationController.any_instance.stubs(:current_user).returns(@admin)
    ApplicationController.any_instance.stubs(:admin_user?).returns(true)
    ApplicationController.any_instance.stubs(:ensure_admin).returns(true)
    Question.delete_all
  end

  def create_question(status: :waiting)
    question = Question.new(asker: users(:two), speaker: @speaker, status: status)
    question.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    question.save!
    question
  end

  test "shows the backlog" do
    create_question

    get admin_questions_url
    assert_response :success
  end

  test "filters by status" do
    create_question(status: :answered)

    get admin_questions_url(status: "waiting")
    assert_response :success
  end

  test "deliver checks the speaker's queue by hand" do
    question = create_question
    Telegram::DeliverQuestion.any_instance.stubs(:call).returns("telegram:11223344:1")

    post deliver_admin_question_url(question)

    assert question.reload.sent?
    assert_redirected_to admin_questions_path
  end
end
