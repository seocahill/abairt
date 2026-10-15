require "test_helper"

class Whatsapp::DeliverQuestionTest < ActiveSupport::TestCase
  def setup
    @speaker = users(:whatsapp_speaker)
    Question.delete_all
    @question = Question.new(asker: users(:two), speaker: @speaker)
    @question.audio.attach(
      io: Rails.root.join("test/fixtures/files/sample.mp3").open,
      filename: "sample.ogg",
      content_type: "audio/ogg",
      identify: false
    )
    @question.save!
    @client = mock("client")
  end

  test "sends the voice note when the window is open" do
    @client.expects(:upload_media).returns("media-1")
    @client.expects(:send_audio).with(to: @speaker.phone_number, media_id: "media-1").returns("wamid.abc")

    assert_equal "whatsapp:wamid.abc", Whatsapp::DeliverQuestion.new(@question, client: @client).call
  end

  test "nudges with a template instead when the window is shut" do
    @speaker.update!(whatsapp_last_inbound_at: 3.days.ago, whatsapp_nudged_at: nil)
    @client.expects(:send_template).with(to: @speaker.phone_number, name: "ceist_nua").returns("wamid.t")
    @client.expects(:send_audio).never

    # Nil because a nudge is not a delivery — the question stays waiting.
    assert_nil Whatsapp::DeliverQuestion.new(@question, client: @client).call
    assert_not_nil @speaker.reload.whatsapp_nudged_at
  end

  test "does not nudge again within the nudge interval" do
    @speaker.update!(whatsapp_last_inbound_at: 3.days.ago, whatsapp_nudged_at: 1.hour.ago)
    @client.expects(:send_template).never

    assert_nil Whatsapp::DeliverQuestion.new(@question, client: @client).call
  end

  test "nudges again once the interval has passed" do
    @speaker.update!(whatsapp_last_inbound_at: 3.days.ago, whatsapp_nudged_at: 2.days.ago)
    @client.expects(:send_template).returns("wamid.t")

    Whatsapp::DeliverQuestion.new(@question, client: @client).call
  end

  test "returns nil rather than raising when whatsapp rejects the send" do
    @client.stubs(:upload_media).raises(Whatsapp::Client::Error, "boom")

    assert_nil Whatsapp::DeliverQuestion.new(@question, client: @client).call
  end
end
