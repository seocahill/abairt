# frozen_string_literal: true

require "test_helper"

class RecordAnswerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  Message = Struct.new(:id, :download_audio)

  def question(asked_via:)
    question = Question.new(asker: users(:admin), speaker: users(:speaker), asked_via: asked_via)
    question.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open, filename: "q.mp3", content_type: "audio/mpeg")
    question.save!
    question.update!(status: :sent, sent_at: Time.current, question_message_id: "telegram:1:#{asked_via}")
    question
  end

  test "files the answer and emails the asker" do
    asked = question(asked_via: "abairt")

    assert_enqueued_emails(1) { RecordAnswer.new(asked, Message.new("telegram:1:2", "ogg")).call }
    assert asked.reload.answered?
    assert asked.answer_audio.attached?
  end

  test "doesn't email for a question asked through the API, whose app shows the answer" do
    asked = question(asked_via: "api")

    assert_no_enqueued_emails { RecordAnswer.new(asked, Message.new("telegram:1:3", "ogg")).call }
    assert asked.reload.answered?
  end
end
