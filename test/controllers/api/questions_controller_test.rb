# frozen_string_literal: true

require "test_helper"

module Api
  class QuestionsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    def setup
      Question.delete_all
      @asker = users(:admin)
      @asker.regenerate_api_token
    end

    def auth(user = @asker) = {"Authorization" => "Bearer #{user.api_token}"}

    def recording(content_type: "audio/webm")
      Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/sample.mp3"), content_type)
    end

    test "needs a token" do
      post api_questions_path, params: {audio: recording}
      assert_response :unauthorized
    end

    test "asks a question on someone's behalf and sends it to a speaker" do
      assert_enqueued_with(job: DeliverNextQuestionJob, args: [users(:speaker)]) do
        post api_questions_path, params: {audio: recording, asker_label: "philip, Mayo Irish course"}, headers: auth
      end

      assert_response :created
      question = Question.sole
      assert question.waiting?
      assert_equal [@asker, "api", "philip, Mayo Irish course"], [question.asker, question.asked_via, question.asker_label]

      json = JSON.parse(response.body)
      assert_equal [question.id, "waiting"], json.values_at("id", "status")
      assert_match %r{/rails/active_storage/blobs/}, json["audio_url"]
      assert_nil json["answer_audio_url"]
    end

    test "takes only audio" do
      post api_questions_path, params: {asker_label: "x"}, headers: auth
      assert_response :unprocessable_entity

      post api_questions_path, params: {audio: recording(content_type: "text/plain")}, headers: auth
      assert_response :unprocessable_entity
      assert_empty Question.all
    end

    test "only accounts allowed to ask can ask" do
      learner = users(:two)
      learner.regenerate_api_token

      post api_questions_path, params: {audio: recording}, headers: auth(learner)

      assert_response :forbidden
      assert_empty Question.all
    end

    test "shows a question's answer once it has one" do
      post api_questions_path, params: {audio: recording}, headers: auth
      question = Question.sole
      question.update!(speaker: users(:speaker), status: :answered, answered_at: Time.current)
      question.answer_audio.attach(io: StringIO.new("ogg"), filename: "answer.ogg", content_type: "audio/ogg")

      get api_question_path(question), headers: auth

      json = JSON.parse(response.body)
      assert_equal "answered", json["status"]
      assert_match %r{answer\.ogg\z}, json["answer_audio_url"]
    end

    test "can't see other accounts' questions" do
      post api_questions_path, params: {audio: recording}, headers: auth
      other = users(:one)
      other.regenerate_api_token

      get api_question_path(Question.sole), headers: auth(other)

      assert_response :not_found
    end
  end
end
