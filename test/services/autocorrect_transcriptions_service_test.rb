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

  test "aligns by word rate when API returns fewer segments than entries" do
    # 2 equal-duration entries (0-2s, 2-4s), 1 segment containing 4 words.
    # Word rate distributes 2 words to each entry proportionally by duration.
    mock_openai(["Dia duit Conas tú"])

    result = @service.process

    assert_equal 2, result
    assert_equal "Dia duit", @entry1.reload.word_or_phrase
    assert_equal "Conas tú", @entry2.reload.word_or_phrase
  end

  test "aligns by word rate when API returns more segments than entries" do
    # 2 equal-duration entries, 3 segments. Words joined then split proportionally.
    mock_openai(["Dia", "duit Conas", "tú"])

    result = @service.process

    assert_equal 2, result
    assert_equal "Dia duit", @entry1.reload.word_or_phrase
    assert_equal "Conas tú", @entry2.reload.word_or_phrase
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

  # Layer 2: sentence boundary snapping
  test "snaps overflow words after a full stop to the next segment" do
    # 4 words → search_from = floor(4 * 0.4) = 1
    # "duit." is at index 1, within the search range → snap
    mock_openai(["Dia duit. Chuaigh sé", "abhaile."])

    @service.process

    assert_equal "Dia duit.", @entry1.reload.word_or_phrase
    assert_equal "Chuaigh sé abhaile.", @entry2.reload.word_or_phrase
  end

  test "does not snap when segment already ends with terminal punctuation" do
    mock_openai(["Dia duit.", "Conas atá tú?"])

    @service.process

    assert_equal "Dia duit.", @entry1.reload.word_or_phrase
    assert_equal "Conas atá tú?", @entry2.reload.word_or_phrase
  end

  test "does not snap when terminal punctuation is only in the first word" do
    # 3 words → search_from = floor(3 * 0.4) = 1
    # "Dia." is at index 0, before search_from → not found → no snap
    mock_openai(["Dia. duit labhair", "sé."])

    @service.process

    assert_equal "Dia. duit labhair", @entry1.reload.word_or_phrase
    assert_equal "sé.", @entry2.reload.word_or_phrase
  end

  test "snaps with question mark boundary" do
    # 4 words → search_from = 1; "tú?" is at index 2 → snap
    mock_openai(["Conas atá tú? Bhí", "sé go maith."])

    @service.process

    assert_equal "Conas atá tú?", @entry1.reload.word_or_phrase
    assert_equal "Bhí sé go maith.", @entry2.reload.word_or_phrase
  end
end
