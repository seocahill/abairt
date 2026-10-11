require "test_helper"

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @asker = users(:two)
    @speaker = users(:whatsapp_speaker)
    ApplicationController.any_instance.stubs(:current_user).returns(@asker)
    Question.delete_all
  end

  def audio_upload
    fixture_file_upload("test/fixtures/files/sample.mp3", "audio/mpeg")
  end

  test "should get index" do
    get questions_url
    assert_response :success
  end

  test "should get new" do
    get new_question_url
    assert_response :success
  end

  test "creates a question and pokes the speaker's queue" do
    assert_difference("Question.count", 1) do
      assert_enqueued_with(job: DeliverNextQuestionJob) do
        post questions_url, params: {audio: audio_upload}
      end
    end

    question = Question.last
    assert_equal @asker, question.asker
    assert_equal @speaker, question.speaker
    assert question.waiting?
    assert_redirected_to new_question_path
  end

  test "responds with a turbo stream so the PWA does not reload" do
    post questions_url, params: {audio: audio_upload}, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.media_type
    assert_match dom_id(Question.last), response.body
  end

  test "will not create a question without audio" do
    assert_no_difference("Question.count") do
      post questions_url
    end

    assert_response :unprocessable_entity
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

    get question_url(mine)
    assert_response :success

    get question_url(theirs)
    assert_response :not_found
  end
end
