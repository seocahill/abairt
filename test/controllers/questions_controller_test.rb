require "test_helper"

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # An admin because the feature is admin-only while in beta. Signed in for
    # real rather than stubbed: ensure_admin reads the session directly, and
    # stubbing current_user would walk straight past the thing under test.
    @asker = users(:two)
    @asker.update!(role: :admin)
    @speaker = users(:speaker)
    sign_in_as(@asker)
    Question.delete_all
  end

  def sign_in_as(user)
    user.regenerate_login_token
    user.save!
    get login_with_token_path(user.login_token)
  end

  def audio_upload
    fixture_file_upload("test/fixtures/files/sample.mp3", "audio/mpeg")
  end

  def create_draft(asker: @asker)
    question = Question.new(asker: asker, speaker: @speaker)
    question.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    question.save!
    question
  end

  test "should get index" do
    get questions_path
    assert_response :success
  end

  test "should get new" do
    get new_question_path
    assert_response :success
  end

  test "records a draft without sending it anywhere" do
    assert_difference("Question.count", 1) do
      assert_no_enqueued_jobs only: DeliverNextQuestionJob do
        post questions_path, params: {audio: audio_upload}
      end
    end

    question = Question.last
    assert_equal @asker, question.asker
    assert_equal @speaker, question.speaker
    assert question.draft?
    assert_redirected_to new_question_path
  end

  test "sending a draft queues it for the speaker" do
    question = create_draft

    assert_enqueued_with(job: DeliverNextQuestionJob) do
      post question_delivery_path(question)
    end

    assert question.reload.waiting?
    assert_redirected_to new_question_path
  end

  test "sending twice does not queue it twice" do
    question = create_draft
    post question_delivery_path(question)

    assert_no_enqueued_jobs only: DeliverNextQuestionJob do
      post question_delivery_path(question)
    end

    assert question.reload.waiting?
  end

  test "deletes a draft" do
    question = create_draft

    assert_difference("Question.count", -1) do
      delete question_path(question)
    end
  end

  test "will not send or delete someone else's question" do
    theirs = create_draft(asker: users(:three))

    post question_delivery_path(theirs)
    assert_response :not_found

    assert_no_difference("Question.count") do
      delete question_path(theirs)
    end
  end

  test "responds with a turbo stream so the PWA does not reload" do
    post questions_path, params: {audio: audio_upload}, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.media_type
    assert_match dom_id(Question.last), response.body
  end

  test "will not create a question without audio" do
    assert_no_difference("Question.count") do
      post questions_path
    end

    assert_response :unprocessable_entity
  end

  # Beta: asking spends a native speaker's time, and soon real money.
  test "a signed-in user who is not an admin cannot reach any of it" do
    sign_in_as(users(:three))

    get questions_path
    assert_redirected_to root_path

    get new_question_path
    assert_redirected_to root_path

    assert_no_difference("Question.count") do
      post questions_path, params: {audio: audio_upload}
    end
    assert_redirected_to root_path
  end

  test "a non-admin cannot send a draft" do
    question = create_draft
    sign_in_as(users(:three))

    assert_no_enqueued_jobs only: DeliverNextQuestionJob do
      post question_delivery_path(question)
    end
    assert_redirected_to root_path
    assert question.reload.draft?
  end

  test "a signed-out visitor is sent to log in" do
    signed_out = open_session

    signed_out.get new_question_path

    signed_out.assert_redirected_to login_path
  end

  test "only shows the asker their own questions" do
    mine = Question.new(asker: @asker, speaker: @speaker)
    mine.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    mine.save!

    theirs = Question.new(asker: users(:three), speaker: @speaker)
    theirs.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    theirs.save!

    get question_path(mine)
    assert_response :success

    get question_path(theirs)
    assert_response :not_found
  end
end
