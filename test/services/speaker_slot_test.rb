require "test_helper"

class SpeakerSlotTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:speaker)
    @speaker.update!(answers_questions: true)
    Question.delete_all
    SegmentPrompt.delete_all
    @slot = SpeakerSlot.new(@speaker)
  end

  def sent_question
    question = Question.new(asker: users(:two), speaker: @speaker, status: :sent)
    question.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    question.save!
    question
  end

  def sent_prompt
    SegmentPrompt.create!(dictionary_entry: dictionary_entries(:one), speaker: @speaker, sent_at: Time.current)
  end

  test "a speaker holding nothing is free" do
    assert @slot.free?
    assert_nil @slot.outstanding
  end

  test "a question they are holding" do
    question = sent_question

    assert_equal question, @slot.outstanding
    assert_not @slot.free?
  end

  # The point of the whole thing: a segment occupies the same slot a question
  # does. A voice note carries no id, so it can only be read as an answer to
  # the one thing they hold — which stops being true if they can hold two.
  test "a segment they are holding fills the same slot" do
    prompt = sent_prompt

    assert_equal prompt, @slot.outstanding
    assert_not @slot.free?
  end

  test "a question wins when somehow both are out" do
    prompt = sent_prompt
    question = sent_question

    assert_equal question, @slot.outstanding
    assert_equal prompt, @slot.segment_prompt
  end

  test "an answered prompt no longer holds the slot" do
    sent_prompt.update!(status: :corrected)

    assert @slot.free?
  end
end
