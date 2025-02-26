require "test_helper"

class FineTuningServiceTest < ActiveSupport::TestCase
  def setup
    @mock_client = mock('openai_client')
    @service = FineTuningService.new(client: @mock_client)
    Current.user = users(:one)

    # Clear existing entries to ensure test isolation
    DictionaryEntry.destroy_all
  end

  test "generates standard Irish and identifies dialectal differences" do
    # Create test entries directly
    entry1 = DictionaryEntry.create!(
      word_or_phrase: "rabh",
      translation: "was",
      standard_irish: nil,
      quality: "good",
      speaker: Current.user,
      owner: Current.user
    )

    entry2 = DictionaryEntry.create!(
      word_or_phrase: "doiligh",
      translation: "difficult",
      standard_irish: "deacair", # Already has standard Irish
      quality: "good",
      speaker: Current.user,
      owner: Current.user
    )

    # Mock OpenAI response
    mock_response = {
      "choices" => [{
        "message" => {
          "content" => {
            "standard_irish" => "raibh",
            "is_significantly_different" => true
          }.to_json
        }
      }]
    }

    # Set up expectation with Mocha - expect exactly one call for the entry without standard Irish
    @mock_client.expects(:chat)
                .with { |params|
                  params[:parameters][:model] == "gpt-4" &&
                  params[:parameters][:response_format] == { type: "json_object" } &&
                  params[:parameters][:messages].any? { |m| m[:role] == "system" } &&
                  params[:parameters][:messages].any? { |m| m[:content].include?("rabh") }
                }
                .returns(mock_response)
                .once

    # Run the service
    result = @service.generate_dataset

    # Verify the entry was updated
    entry1.reload
    assert_equal "raibh", entry1.standard_irish

    # Verify JSONL files were created with correct format
    assert File.exist?("training_data.jsonl")
    assert File.exist?("validation_data.jsonl")

    # Check content of training file
    training_content = File.read("training_data.jsonl")
    training_examples = training_content.split("\n").map { |line| JSON.parse(line) }

    # Check content of validation file
    validation_content = File.read("validation_data.jsonl")
    validation_examples = validation_content.split("\n").map { |line| JSON.parse(line) }

    # Verify "rabh" is in either file
    assert training_examples.any? { |ex| ex.dig("messages", 2, "content") == "rabh" } ||
           validation_examples.any? { |ex| ex.dig("messages", 2, "content") == "rabh" },
           "Should find example for 'rabh' in either file"

    # Verify "doiligh" is in either file
    assert training_examples.any? { |ex| ex.dig("messages", 2, "content") == "doiligh" } ||
           validation_examples.any? { |ex| ex.dig("messages", 2, "content") == "doiligh" },
           "Should find example for 'doiligh' in either file"

    # Clean up
    File.delete("training_data.jsonl")
    File.delete("validation_data.jsonl")
  end

  test "skips entries without significant dialectal differences" do
    # Create test entry directly
    entry = DictionaryEntry.create!(
      word_or_phrase: "bád",
      translation: "boat",
      standard_irish: nil,
      quality: "good",
      speaker: Current.user,
      owner: Current.user
    )

    # Mock OpenAI response indicating no significant difference
    mock_response = {
      "choices" => [{
        "message" => {
          "content" => {
            "standard_irish" => "bád",
            "is_significantly_different" => false
          }.to_json
        }
      }]
    }

    # Expect exactly one call for this specific entry
    @mock_client.expects(:chat)
                .with { |params|
                  params[:parameters][:messages].any? { |m| m[:content].include?("bád") }
                }
                .returns(mock_response)
                .once

    result = @service.generate_dataset

    # The entry should not be included in the training data
    training_content = File.read("training_data.jsonl")
    training_examples = training_content.split("\n").map { |line| JSON.parse(line) }

    assert_empty training_examples, "Should not include entries without dialectal differences"

    # Clean up
    File.delete("training_data.jsonl")
    File.delete("validation_data.jsonl")
  end

  test "estimates costs correctly" do
    # Create test entries directly
    entry1 = DictionaryEntry.create!(
      word_or_phrase: "rabh",
      translation: "was",
      standard_irish: nil,
      quality: "good",
      speaker: Current.user,
      owner: Current.user
    )

    entry2 = DictionaryEntry.create!(
      word_or_phrase: "doiligh",
      translation: "difficult",
      standard_irish: "deacair",
      quality: "good",
      speaker: Current.user,
      owner: Current.user
    )

    # Run cost estimation
    result = @service.estimate_cost

    # Basic structure checks
    assert_kind_of Hash, result
    assert_includes result, :total_entries
    assert_includes result, :missing_standard
    assert_includes result, :gpt4_costs
    assert_includes result, :fine_tuning_costs

    # GPT-4 costs
    assert_kind_of Hash, result[:gpt4_costs]
    assert result[:gpt4_costs][:input_cost] > 0
    assert result[:gpt4_costs][:output_cost] > 0

    # Fine-tuning costs
    assert_kind_of Hash, result[:fine_tuning_costs]
    assert result[:fine_tuning_costs][:cost] > 0
    assert result[:fine_tuning_costs][:total_tokens] > 0
  end
end
