require "test_helper"

class SegmentQueueTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:speaker)
    @speaker.update!(answers_questions: true)
    @recording = voice_recordings(:one)
    @recording.update!(claimed_by: @speaker)
    Question.delete_all
    SegmentPrompt.delete_all
    DictionaryEntry.delete_all
    @queue = SegmentQueue.new(@speaker)
  end

  def create_entry(recording: @recording, text: "Dia dhuit", region_start: 1.0, media: true)
    entry = DictionaryEntry.new(
      word_or_phrase: text, owner: users(:one), voice_recording: recording,
      region_start: region_start, region_end: region_start + 2
    )
    if media
      entry.media.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
        filename: "sample.mp3", content_type: "audio/mpeg")
    end
    entry.save!
    entry
  end

  def stub_send(message_id: "telegram:11223344:9")
    Telegram::DeliverSegment.any_instance.stubs(:call).returns(message_id)
  end

  test "sends the earliest unchecked segment of a claimed recording" do
    later = create_entry(text: "Slán", region_start: 20.0)
    first = create_entry(text: "Dia dhuit", region_start: 1.0)
    stub_send

    prompt = @queue.deliver_next

    assert_equal first, prompt.dictionary_entry
    assert_equal @speaker, prompt.speaker
    assert_not_equal later, prompt.dictionary_entry
  end

  # The claim decides whose Telegram the prompts go to. It is not a lock on
  # translating: anybody may still work on that recording in the web app.
  test "ignores recordings this speaker has not claimed" do
    @recording.update!(claimed_by: users(:one))
    create_entry
    Telegram::DeliverSegment.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  test "sends nothing while they are already holding a segment" do
    create_entry
    SegmentPrompt.create!(dictionary_entry: create_entry(region_start: 30.0), speaker: @speaker, sent_at: Time.current)
    Telegram::DeliverSegment.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  # The slot is shared, so a question out with them blocks a segment too.
  test "sends nothing while they are holding a question" do
    create_entry
    question = Question.new(asker: users(:two), speaker: @speaker, status: :sent)
    question.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    question.save!
    Telegram::DeliverSegment.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  # A learner is waiting on a question; a segment is only filling a quiet week.
  test "a waiting question comes first" do
    create_entry
    question = Question.new(asker: users(:two), speaker: @speaker, status: :waiting)
    question.audio.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    question.save!
    Telegram::DeliverSegment.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  test "does not ask about a segment twice" do
    entry = create_entry
    SegmentPrompt.create!(dictionary_entry: entry, speaker: @speaker, status: :confirmed)
    Telegram::DeliverSegment.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  test "skips a segment with no audio to send" do
    create_entry(media: false)
    Telegram::DeliverSegment.any_instance.expects(:call).never

    assert_nil @queue.deliver_next
  end

  test "a segment that could not be sent leaves no prompt behind" do
    create_entry
    Telegram::DeliverSegment.any_instance.stubs(:call).returns(nil)

    assert_no_difference("SegmentPrompt.count") { @queue.deliver_next }
  end
end
