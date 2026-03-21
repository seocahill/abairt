# frozen_string_literal: true

require "test_helper"

class IslandContextServiceTest < ActiveSupport::TestCase
  def setup
    @service = IslandContextService.new("ordering food in a pub")
  end

  test "call returns merged FTS and vector results" do
    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)

    @service.stubs(:extract_keywords).returns(["food", "drink"])
    @service.stubs(:fts_search).with(["food", "drink"]).returns([entry_one])
    @service.stubs(:vector_search).returns([entry_one, entry_two])

    result = @service.call
    assert_equal [entry_one, entry_two], result
  end

  test "call deduplicates entries across FTS and vector" do
    entry = dictionary_entries(:two)

    @service.stubs(:extract_keywords).returns(["hello"])
    @service.stubs(:fts_search).returns([entry])
    @service.stubs(:vector_search).returns([entry])

    result = @service.call
    assert_equal [entry], result
  end

  test "call respects limit" do
    service = IslandContextService.new("test", limit: 2)
    entries = [dictionary_entries(:one), dictionary_entries(:two), dictionary_entries(:three)]

    service.stubs(:extract_keywords).returns(["test"])
    service.stubs(:fts_search).returns(entries)
    service.stubs(:vector_search).returns([])

    result = service.call
    assert_equal 2, result.size
  end

  test "limit is capped at MAX_LIMIT" do
    service = IslandContextService.new("test", limit: 100)
    service.stubs(:extract_keywords).returns([])
    service.stubs(:fts_search).returns([])
    service.stubs(:vector_search).returns([])

    service.call
    assert_equal 50, service.instance_variable_get(:@limit)
  end

  test "FTS results appear before vector-only results" do
    fts_entry = dictionary_entries(:one)
    vector_entry = dictionary_entries(:two)

    @service.stubs(:extract_keywords).returns(["hello"])
    @service.stubs(:fts_search).returns([fts_entry])
    @service.stubs(:vector_search).returns([vector_entry])

    result = @service.call
    assert_equal fts_entry, result.first
    assert_equal vector_entry, result.last
  end

  test "extract_keywords calls OpenAI and parses response" do
    keywords_json = '{"keywords": ["hello", "goodbye", "weather"]}'
    mock_response = {
      "choices" => [{ "message" => { "content" => keywords_json } }]
    }

    mock_client = mock("OpenAI::Client")
    mock_client.expects(:chat).returns(mock_response)
    OpenAI::Client.stubs(:new).returns(mock_client)

    result = @service.send(:extract_keywords)
    assert_equal ["hello", "goodbye", "weather"], result
  end

  test "extract_keywords returns empty array on error" do
    OpenAI::Client.stubs(:new).raises(StandardError.new("API error"))

    result = @service.send(:extract_keywords)
    assert_equal [], result
  end

  test "extract_keywords caps at MAX_KEYWORDS" do
    keywords = (1..20).map { |i| "word#{i}" }
    keywords_json = { keywords: keywords }.to_json
    mock_response = {
      "choices" => [{ "message" => { "content" => keywords_json } }]
    }

    mock_client = mock("OpenAI::Client")
    mock_client.stubs(:chat).returns(mock_response)
    OpenAI::Client.stubs(:new).returns(mock_client)

    result = @service.send(:extract_keywords)
    assert_equal 12, result.size
  end

  test "fts_search returns empty array for empty keywords" do
    result = @service.send(:fts_search, [])
    assert_equal [], result
  end

  test "vector_search delegates to EmbeddingService" do
    entry = dictionary_entries(:two)

    mock_embedding_service = mock("EmbeddingService")
    mock_embedding_service.expects(:search).with("ordering food in a pub", limit: 20).returns([entry])
    EmbeddingService.stubs(:new).returns(mock_embedding_service)

    # Stub the audio filter to pass through
    DictionaryEntry.stubs(:has_recording).returns(DictionaryEntry.where(id: entry.id))

    result = @service.send(:vector_search)
    assert_includes result, entry
  end

  test "vector_search returns empty array on error" do
    EmbeddingService.stubs(:new).raises(StandardError.new("API error"))

    result = @service.send(:vector_search)
    assert_equal [], result
  end

  test "filter_to_with_audio removes entries without recordings" do
    entry_without_recording = dictionary_entries(:one) # no voice_recording, no media attachment
    entry_with_recording = dictionary_entries(:with_temp_speaker) # has voice_recording

    # We can only test entries that actually have media attachments in fixtures
    # Since most fixture entries don't have media, filter should exclude them
    result = @service.send(:filter_to_with_audio, [entry_without_recording])
    assert_equal [], result
  end

  test "filter_to_with_audio returns empty for empty input" do
    result = @service.send(:filter_to_with_audio, [])
    assert_equal [], result
  end
end
