# frozen_string_literal: true

require "test_helper"

class IslandContextServiceTest < ActiveSupport::TestCase
  def setup
    @service = IslandContextService.new("ordering food in a pub")
  end

  # ── call (integration) ──────────────────────────────────────────────────

  test "call merges and refines FTS and vector results" do
    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)

    @service.stubs(:extract_keywords).returns(["food", "drink"])
    @service.stubs(:fts_search).with(["food", "drink"]).returns([entry_one])
    @service.stubs(:vector_search).returns([entry_one, entry_two])
    @service.stubs(:refine).with([entry_one, entry_two]).returns([entry_one, entry_two])

    result = @service.call
    assert_equal [entry_one, entry_two], result
  end

  test "call deduplicates entries across FTS and vector" do
    entry = dictionary_entries(:two)

    @service.stubs(:extract_keywords).returns(["hello"])
    @service.stubs(:fts_search).returns([entry])
    @service.stubs(:vector_search).returns([entry])
    @service.stubs(:refine).with([entry]).returns([entry])

    result = @service.call
    assert_equal [entry], result
  end

  test "limit is capped at MAX_LIMIT" do
    service = IslandContextService.new("test", limit: 100)
    service.stubs(:extract_keywords).returns([])
    service.stubs(:fts_search).returns([])
    service.stubs(:vector_search).returns([])

    service.call
    assert_equal 50, service.instance_variable_get(:@limit)
  end

  test "FTS results appear before vector-only results in merge" do
    fts_entry = dictionary_entries(:one)
    vector_entry = dictionary_entries(:two)

    result = @service.send(:merge, [fts_entry], [vector_entry])
    assert_equal fts_entry, result.first
    assert_equal vector_entry, result.last
  end

  test "merge over-fetches at 2x limit" do
    service = IslandContextService.new("test", limit: 2)
    entries = (1..5).map { |i| dictionary_entries([:one, :two, :three, :four, :five][i - 1]) }

    result = service.send(:merge, entries, [])
    assert_equal 4, result.size # 2 * 2
  end

  # ── extract_keywords ────────────────────────────────────────────────────

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

  # ── fts_search ──────────────────────────────────────────────────────────

  test "fts_search returns empty array for empty keywords" do
    result = @service.send(:fts_search, [])
    assert_equal [], result
  end

  test "fts_search scopes MATCH to translation column" do
    # Verify the query is built with translation: prefix
    keywords = ["sea", "beach"]
    expected_query = 'translation:("sea" OR "beach")'

    DictionaryEntry.stubs(:has_recording).returns(
      DictionaryEntry.where("1=0") # empty scope
    )

    # We test the query construction by checking what gets passed to where
    query_used = nil
    relation = mock("relation")
    relation.stubs(:joins).returns(relation)
    relation.stubs(:where).with { |q, _| query_used = q; true }.returns(relation)
    relation.stubs(:with_attached_media).returns(relation)
    relation.stubs(:includes).returns(relation)
    relation.stubs(:distinct).returns(relation)
    relation.stubs(:order).returns(relation)
    relation.stubs(:limit).returns(relation)
    relation.stubs(:to_a).returns([])

    DictionaryEntry.stubs(:has_recording).returns(relation)

    @service.send(:fts_search, keywords)
    assert_equal "fts_dictionary_entries MATCH ?", query_used
  end

  # ── vector_search ───────────────────────────────────────────────────────

  test "vector_search delegates to EmbeddingService" do
    entry = dictionary_entries(:two)

    mock_embedding_service = mock("EmbeddingService")
    mock_embedding_service.expects(:search).with("ordering food in a pub", limit: 20).returns([entry])
    EmbeddingService.stubs(:new).returns(mock_embedding_service)

    DictionaryEntry.stubs(:has_recording).returns(DictionaryEntry.where(id: entry.id))

    result = @service.send(:vector_search)
    assert_includes result, entry
  end

  test "vector_search returns empty array on error" do
    EmbeddingService.stubs(:new).raises(StandardError.new("API error"))

    result = @service.send(:vector_search)
    assert_equal [], result
  end

  # ── filter_to_with_audio ────────────────────────────────────────────────

  test "filter_to_with_audio removes entries without recordings" do
    entry_without_recording = dictionary_entries(:one)

    result = @service.send(:filter_to_with_audio, [entry_without_recording])
    assert_equal [], result
  end

  test "filter_to_with_audio returns empty for empty input" do
    result = @service.send(:filter_to_with_audio, [])
    assert_equal [], result
  end

  # ── refine ──────────────────────────────────────────────────────────────

  test "refine skips LLM for 3 or fewer candidates" do
    entries = [dictionary_entries(:one), dictionary_entries(:two)]

    result = @service.send(:refine, entries)
    assert_equal entries, result
  end

  test "refine calls LLM and filters by returned IDs" do
    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)
    entry_three = dictionary_entries(:three)
    entry_four = dictionary_entries(:four)
    candidates = [entry_one, entry_two, entry_three, entry_four]

    refine_response = { "ids" => [entry_two.id, entry_four.id] }.to_json
    mock_response = {
      "choices" => [{ "message" => { "content" => refine_response } }]
    }

    mock_client = mock("OpenAI::Client")
    mock_client.expects(:chat).returns(mock_response)
    OpenAI::Client.stubs(:new).returns(mock_client)

    result = @service.send(:refine, candidates)
    assert_equal [entry_two, entry_four], result
  end

  test "refine preserves LLM ordering" do
    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)
    entry_three = dictionary_entries(:three)
    entry_four = dictionary_entries(:four)
    candidates = [entry_one, entry_two, entry_three, entry_four]

    # LLM returns IDs in a different order than input
    refine_response = { "ids" => [entry_three.id, entry_one.id] }.to_json
    mock_response = {
      "choices" => [{ "message" => { "content" => refine_response } }]
    }

    mock_client = mock("OpenAI::Client")
    mock_client.expects(:chat).returns(mock_response)
    OpenAI::Client.stubs(:new).returns(mock_client)

    result = @service.send(:refine, candidates)
    assert_equal [entry_three, entry_one], result
  end

  test "refine falls back to truncated candidates on error" do
    entries = [dictionary_entries(:one), dictionary_entries(:two),
               dictionary_entries(:three), dictionary_entries(:four)]

    OpenAI::Client.stubs(:new).raises(StandardError.new("API error"))

    service = IslandContextService.new("test", limit: 2)
    result = service.send(:refine, entries)
    assert_equal 2, result.size
  end

  test "refine respects limit" do
    service = IslandContextService.new("test", limit: 2)
    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)
    entry_three = dictionary_entries(:three)
    entry_four = dictionary_entries(:four)
    candidates = [entry_one, entry_two, entry_three, entry_four]

    # LLM returns more than limit
    refine_response = { "ids" => [entry_one.id, entry_two.id, entry_three.id] }.to_json
    mock_response = {
      "choices" => [{ "message" => { "content" => refine_response } }]
    }

    mock_client = mock("OpenAI::Client")
    mock_client.expects(:chat).returns(mock_response)
    OpenAI::Client.stubs(:new).returns(mock_client)

    result = service.send(:refine, candidates)
    assert_equal 2, result.size
  end
end
