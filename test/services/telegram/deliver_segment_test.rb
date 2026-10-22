require "test_helper"

class Telegram::DeliverSegmentTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:speaker)
    @client = mock("client")
  end

  def entry(text: "Dia dhuit")
    entry = DictionaryEntry.new(
      word_or_phrase: text, owner: users(:one),
      voice_recording: voice_recordings(:one), region_start: 1.0, region_end: 3.0
    )
    entry.media.attach(io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.mp3", content_type: "audio/mpeg")
    entry.save!
    entry
  end

  # Two ways to answer and nothing to read: the clip, what we currently think
  # it says, and one key above the keyboard.
  test "sends the clip with the transcription and one button" do
    @client.expects(:send_voice).with { |args|
      args[:chat_id] == @speaker.telegram_chat_id &&
        args[:caption].include?("Dia dhuit") &&
        args[:button] == Telegram::DeliverSegment::CONFIRM
    }.returns(42)

    id = Telegram::DeliverSegment.new(entry, @speaker, client: @client).call

    assert_equal "telegram:#{@speaker.telegram_chat_id}:42", id
  end

  test "a segment with no transcription yet still goes out" do
    @client.expects(:send_voice).with { |args|
      args[:caption].include?(Telegram::DeliverSegment::NO_TEXT)
    }.returns(42)

    assert_not_nil Telegram::DeliverSegment.new(entry(text: nil), @speaker, client: @client).call
  end

  # The segment is offered again next time rather than wedging the queue.
  test "returns nil when it could not be sent" do
    @client.expects(:send_voice).raises(Telegram::Client::Error, "boom")

    assert_nil Telegram::DeliverSegment.new(entry, @speaker, client: @client).call
  end
end
