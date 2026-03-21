# frozen_string_literal: true

require "test_helper"

class EmbeddingServiceTest < ActiveSupport::TestCase
  def setup
    @entry = dictionary_entries(:two) # confirmed, has translation
    @fake_vector = Array.new(1536) { rand(-1.0..1.0) }
    @mock_client = mock("OpenAI::Client")
    OpenAI::Client.stubs(:new).returns(@mock_client)
  end

  test "generate calls OpenAI embeddings API and returns vector" do
    mock_response = { "data" => [{ "embedding" => @fake_vector }] }
    @mock_client.expects(:embeddings).with(
      parameters: { model: "text-embedding-3-small", input: "test query" }
    ).returns(mock_response)

    result = EmbeddingService.new.generate("test query")
    assert_equal @fake_vector, result
  end

  test "generate truncates long text to 8000 chars" do
    long_text = "a" * 10_000
    mock_response = { "data" => [{ "embedding" => @fake_vector }] }
    @mock_client.expects(:embeddings).with { |params|
      params[:parameters][:input].length <= 8003 # 8000 + "..."
    }.returns(mock_response)

    EmbeddingService.new.generate(long_text)
  end

  test "store embeds only the English translation" do
    @mock_client.expects(:embeddings).with { |params|
      params[:parameters][:input] == @entry.translation
    }.returns({ "data" => [{ "embedding" => @fake_vector }] })

    db = ActiveRecord::Base.connection.raw_connection
    db.stubs(:execute)

    EmbeddingService.new.store(@entry)
  end

  test "store deletes existing embedding before inserting" do
    @mock_client.stubs(:embeddings).returns({ "data" => [{ "embedding" => @fake_vector }] })

    db = ActiveRecord::Base.connection.raw_connection
    delete_called = false
    insert_called = false

    db.stubs(:execute).with { |sql, _params|
      if sql.include?("DELETE")
        delete_called = true
        assert_includes sql, "vec_dictionary_entry_embeddings"
      elsif sql.include?("INSERT")
        insert_called = true
        assert_includes sql, "vec_dictionary_entry_embeddings"
      end
      true
    }

    EmbeddingService.new.store(@entry)
    assert delete_called, "Expected DELETE to be called"
    assert insert_called, "Expected INSERT to be called"
  end

  test "search returns DictionaryEntry.none when vector is nil" do
    @mock_client.stubs(:embeddings).returns({ "data" => [{ "embedding" => nil }] })

    result = EmbeddingService.new.search("test")
    assert_equal DictionaryEntry.none, result
  end

  test "search returns entries ordered by vector distance" do
    @mock_client.stubs(:embeddings).returns({ "data" => [{ "embedding" => @fake_vector }] })

    entry_one = dictionary_entries(:one)
    entry_two = dictionary_entries(:two)

    db = ActiveRecord::Base.connection.raw_connection
    db.stubs(:execute).with { |sql, _| sql.include?("MATCH") }.returns([
      { "dictionary_entry_id" => entry_two.id, "distance" => 0.1 },
      { "dictionary_entry_id" => entry_one.id, "distance" => 0.3 }
    ])

    result = EmbeddingService.new.search("test query")
    assert_equal [entry_two, entry_one], result
  end

  test "search returns empty relation on error" do
    @mock_client.stubs(:embeddings).raises(StandardError.new("API error"))

    result = EmbeddingService.new.search("test")
    assert_empty result
  end

  test "self.generate delegates to instance" do
    mock_response = { "data" => [{ "embedding" => @fake_vector }] }
    @mock_client.stubs(:embeddings).returns(mock_response)

    result = EmbeddingService.generate("test")
    assert_equal @fake_vector, result
  end
end
