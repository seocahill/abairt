# frozen_string_literal: true

require "test_helper"

class AutocorrectTranscriptionsServiceTest < ActiveSupport::TestCase
  def setup
    @voice_recording = voice_recordings(:two)
    @voice_recording.update_columns(transcription: "Dia duit. Conas atá tú?")

    @entry1 = dictionary_entries(:one)
    @entry2 = dictionary_entries(:five)
    @entry1.update_columns(voice_recording_id: @voice_recording.id, region_start: 0.0, region_end: 2.0, word_or_phrase: "Dia doit")
    @entry2.update_columns(voice_recording_id: @voice_recording.id, region_start: 2.0, region_end: 4.0, word_or_phrase: "Conas ata tu")

    @service = AutocorrectTranscriptionsService.new(@voice_recording)
  end

  def mock_openai(segments)
    content = JSON.generate({ "segments" => segments })
    mock_response = { "choices" => [{ "message" => { "content" => content } }] }
    mock_client = mock("OpenAI::Client")
    mock_client.stubs(:chat).returns(mock_response)
    OpenAI::Client.stubs(:new).returns(mock_client)
  end

  test "returns nil when no transcription" do
    @voice_recording.update_columns(transcription: nil)
    assert_nil @service.process
  end

  test "returns 0 when no entries" do
    @entry1.update_columns(voice_recording_id: nil)
    @entry2.update_columns(voice_recording_id: nil)
    assert_equal 0, @service.process
  end

  test "updates unconfirmed entries with corrected text" do
    mock_openai(["Dia duit", "Conas atá tú?"])

    result = @service.process

    assert_equal 2, result
    assert_equal "Dia duit", @entry1.reload.word_or_phrase
    assert_equal "Conas atá tú?", @entry2.reload.word_or_phrase
  end

  test "clears translation when updating entry" do
    @entry1.update_columns(translation: "Hello there")
    mock_openai(["Dia duit", "Conas atá tú?"])

    @service.process

    assert_nil @entry1.reload.translation
  end

  test "skips confirmed entries" do
    @entry2.update_columns(accuracy_status: 1)
    mock_openai(["Dia duit", "Conas atá tú?"])

    result = @service.process

    assert_equal 1, result
    assert_equal "Dia duit", @entry1.reload.word_or_phrase
    assert_equal "Conas ata tu", @entry2.reload.word_or_phrase  # confirmed, skipped
  end

  test "skips entries where corrected text matches existing" do
    @entry1.update_columns(word_or_phrase: "Dia duit")
    mock_openai(["Dia duit", "Conas atá tú?"])

    result = @service.process

    assert_equal 1, result
  end

  test "skips blank corrected texts" do
    mock_openai(["", "Conas atá tú?"])

    result = @service.process

    assert_equal 1, result
    assert_equal "Dia doit", @entry1.reload.word_or_phrase
  end

  test "aligns by timestamp when API returns fewer segments than entries" do
    # 1 corrected text for 2 entries: both entries map to index 0 of corrected_texts
    # entry1 midpoint = 1.0s, entry2 midpoint = 3.0s, total range 0–4s
    # proportional positions: 0.25 and 0.75 → both floor to idx 0 of a 1-element array
    mock_openai(["Dia duit"])

    result = @service.process

    assert_equal 2, result
    assert_equal "Dia duit", @entry1.reload.word_or_phrase
    assert_equal "Dia duit", @entry2.reload.word_or_phrase
  end

  test "returns nil when API response is empty" do
    mock_response = { "choices" => [{ "message" => { "content" => nil } }] }
    mock_client = mock("OpenAI::Client")
    mock_client.stubs(:chat).returns(mock_response)
    OpenAI::Client.stubs(:new).returns(mock_client)

    assert_nil @service.process
  end

  test "returns nil on JSON parse error" do
    mock_client = mock("OpenAI::Client")
    mock_client.stubs(:chat).returns({ "choices" => [{ "message" => { "content" => "not json" } }] })
    OpenAI::Client.stubs(:new).returns(mock_client)

    assert_nil @service.process
  end

  test "returns nil on unexpected error" do
    OpenAI::Client.stubs(:new).raises(StandardError.new("network error"))

    assert_nil @service.process
  end

  test "strips whitespace from corrected text" do
    mock_openai(["  Dia duit  ", "  Conas atá tú?  "])

    @service.process

    assert_equal "Dia duit", @entry1.reload.word_or_phrase
    assert_equal "Conas atá tú?", @entry2.reload.word_or_phrase
  end
end
