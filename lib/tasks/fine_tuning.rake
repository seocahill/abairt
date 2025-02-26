namespace :fine_tuning do
  desc "Estimate costs for fine-tuning dataset generation and training"
  task estimate_cost: :environment do
    result = FineTuningService.new.estimate_cost

    puts "\nCost Estimation for Fine-tuning Dataset"
    puts "----------------------------------------"
    puts "Total dictionary entries: #{result[:total_entries]}"
    puts "Entries missing standard Irish: #{result[:missing_standard]}"
    puts "\nToken Counts:"
    puts "- Average tokens per GPT-4 prompt: #{result[:gpt4_costs][:avg_prompt_tokens]}"
    puts "- Average tokens per training example: #{result[:fine_tuning_costs][:avg_tokens_per_example]}"
    puts "\nGPT-4 Standard Irish Generation:"
    puts "- Input cost: $#{result[:gpt4_costs][:input_cost].round(2)}"
    puts "- Output cost: $#{result[:gpt4_costs][:output_cost].round(2)}"
    puts "- Total GPT-4 cost: $#{(result[:gpt4_costs][:input_cost] + result[:gpt4_costs][:output_cost]).round(2)}"
    puts "\nFine-tuning Dataset:"
    puts "- Total examples: #{result[:fine_tuning_costs][:total_examples]}"
    puts "- Estimated total tokens: #{result[:fine_tuning_costs][:total_tokens]}"
    puts "- Fine-tuning cost: $#{result[:fine_tuning_costs][:cost].round(2)}"
    puts "\nTotal estimated cost: $#{(result[:gpt4_costs][:input_cost] + result[:gpt4_costs][:output_cost] + result[:fine_tuning_costs][:cost]).round(2)}"
    puts "\nNote: These estimates use actual token counts from your data, but costs may vary based on:"
    puts "- Actual response lengths from GPT-4"
    puts "- Number of training epochs"
    puts "- Any additional API calls for testing"
  end

  desc "Generate fine-tuning dataset from dictionary entries"
  task generate: :environment do
    result = FineTuningService.new.generate_dataset

    puts "\nDataset generation complete!"
    puts "Training examples: #{result[:training][:examples]}"
    puts "Validation examples: #{result[:validation][:examples]}"
    puts "\nFiles generated:"
    puts "- #{result[:training][:path]}"
    puts "- #{result[:validation][:path]}"
    puts "\nNote: Only entries with significant dialectal differences were included in the dataset."
    puts "You can now validate the data using:"
    puts "openai tools fine_tunes.prepare_data -f #{result[:training][:path]}"
  end
end
