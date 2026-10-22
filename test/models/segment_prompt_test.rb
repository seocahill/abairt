require "test_helper"

class SegmentPromptTest < ActiveSupport::TestCase
  def setup
    @entry = dictionary_entries(:one)
    @prompt = SegmentPrompt.create!(dictionary_entry: @entry, speaker: users(:speaker), sent_at: Time.current)
  end

  def voice_note(bytes = "ogg-bytes")
    message = mock("message")
    message.stubs(:download_audio).returns(bytes)
    message
  end

  test "tapping the button confirms the entry itself" do
    @prompt.confirm!

    assert @prompt.confirmed?
    assert @entry.reload.confirmed?
    assert_not_nil @prompt.answered_at
  end

  # A voice note is an annotation, not an edit. Confirming the entry here would
  # claim the transcript had been fixed when nobody has written it down yet.
  test "a correction leaves the entry unconfirmed and queues the audio" do
    assert @prompt.record_correction!(voice_note)

    assert @prompt.corrected?
    assert @prompt.correction_audio.attached?
    assert @entry.reload.unconfirmed?
    assert_includes SegmentPrompt.to_apply, @prompt
  end

  test "the correction keeps the type Telegram declared" do
    @prompt.record_correction!(voice_note)

    assert_equal "audio/ogg", @prompt.correction_audio.content_type
  end

  # Telegram redelivers anything it did not get a 200 for.
  test "the same correction arriving twice attaches once" do
    @prompt.record_correction!(voice_note)

    assert_not @prompt.record_correction!(voice_note)
    assert_equal 1, @prompt.correction_audio.attachments.size
  end
end
