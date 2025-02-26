class FineTuningService
  PROMPT_TEMPLATES = [
    "Translate the English sentence, '%<sentence>s', into Mayo Irish.",
    "What is the Mayo Irish equivalent of: '%<sentence>s'?",
    "How would you say '%<sentence>s' in the Mayo dialect of Irish?"
  ].freeze

  GPT4_INPUT_COST_PER_1K = 0.03
  GPT4_OUTPUT_COST_PER_1K = 0.06
  GPT35_FINETUNE_COST_PER_1K = 0.008

  def initialize(client: nil)
    @client = client || OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org))
  end

  def generate_dataset
    entries = fetch_entries
    dialectal_entries = generate_standard_irish(entries)
    generate_jsonl_files(dialectal_entries)
  end

  def estimate_cost
    require "tiktoken_ruby"
    tokenizer = Tiktoken.encoding_for_model("gpt-3.5-turbo")

    entries = fetch_entries
    missing_count = entries.where(standard_irish: [nil, ""]).count
    sample_entries = entries.where(standard_irish: [nil, ""]).limit(10)

    {
      total_entries: entries.count,
      missing_standard: missing_count,
      gpt4_costs: calculate_gpt4_costs(sample_entries, tokenizer),
      fine_tuning_costs: calculate_fine_tuning_costs(entries, tokenizer)
    }
  end

  private

  def fetch_entries
    DictionaryEntry.where(quality: ["good", "excellent"])
  end

  def generate_standard_irish(entries)
    dialectal_entries = []

    entries.where(standard_irish: [nil, ""]).each do |entry|
      response = request_standard_irish(entry)

      begin
        response_data = JSON.parse(response.dig("choices", 0, "message", "content"))
        standard_irish = response_data["standard_irish"]
        is_significantly_different = response_data["is_significantly_different"]

        next if standard_irish.nil? || standard_irish.empty?

        if is_significantly_different
          entry.update_columns(standard_irish: standard_irish)
          dialectal_entries << entry
        end
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse response for entry #{entry.id}: #{e.message}")
        next
      end
    end

    # Add existing entries that already have standard Irish translations
    existing_entries = entries.where.not(standard_irish: [nil, ""])
    dialectal_entries + existing_entries.to_a
  end

  def request_standard_irish(entry)
    prompt = <<~PROMPT
      The following is a phrase in the Mayo dialect of Irish: '#{entry.word_or_phrase}'.
      Its English translation is: '#{entry.translation}'.

      Please analyze this phrase and provide:
      1. The standard Irish equivalent
      2. Whether there is a significant dialectal difference between the Mayo version and standard Irish

      Consider differences in:
      - Vocabulary choice
      - Grammatical structure
      - Pronunciation-reflecting spelling
      - Regional variations

      Only consider it significantly different if there are meaningful dialectal variations, not just minor spelling differences.
    PROMPT

    @client.chat(
      parameters: {
        model: "gpt-4o",
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You are an expert linguist specializing in Irish Gaelic. Return a JSON object with keys 'standard_irish' (the standard Irish translation) and 'is_significantly_different' (boolean indicating if there are meaningful dialectal differences)."
          },
          { role: "user", content: prompt }
        ],
        temperature: 0.7
      }
    )
  end

  def generate_jsonl_files(dialectal_entries)
    # Ensure files are created even if there are no entries
    File.write("training_data.jsonl", "")
    File.write("validation_data.jsonl", "")

    return { training: { path: "training_data.jsonl", examples: 0 },
             validation: { path: "validation_data.jsonl", examples: 0 }
    } if dialectal_entries.empty?

    entries_array = dialectal_entries.to_a.shuffle
    split_index = (entries_array.size * 0.8).floor

    training_set = entries_array[0...split_index]
    validation_set = entries_array[split_index..]

    {
      training: generate_jsonl_file(training_set, "training_data.jsonl"),
      validation: generate_jsonl_file(validation_set, "validation_data.jsonl")
    }
  end

  def generate_jsonl_file(entries, filename)
    return { path: filename, examples: 0 } if entries.empty?

    File.open(filename, "w") do |file|
      entries.each do |entry|
        # English to Mayo Irish example
        english_prompt = format(PROMPT_TEMPLATES.sample, sentence: entry.translation)
        file.puts JSON.generate({
          messages: [
            { role: "system", content: "You are an Irish assistant specializing in the Mayo dialect." },
            { role: "user", content: english_prompt },
            { role: "assistant", content: entry.word_or_phrase }
          ]
        })

        # Standard Irish to Mayo Irish example
        file.puts JSON.generate({
          messages: [
            { role: "system", content: "You are an Irish assistant specializing in the Mayo dialect." },
            { role: "user", content: "#{entry.standard_irish} (standard Irish)" },
            { role: "assistant", content: "#{entry.word_or_phrase} (Mayo Irish)" }
          ]
        })
      end
    end

    {
      path: filename,
      examples: entries.size * 2
    }
  end

  def calculate_gpt4_costs(sample_entries, tokenizer)
    system_msg = "You are an expert linguist specializing in Irish Gaelic. Return a JSON object with keys 'standard_irish' and 'is_significantly_different'."
    prompt_template = <<~PROMPT.strip
      The following is a phrase in the Mayo dialect of Irish: '%s'.
      Its English translation is: '%s'.
      Please analyze this phrase...
    PROMPT

    total_prompt_tokens = 0
    sample_entries.each do |entry|
      prompt = format(prompt_template, entry.word_or_phrase, entry.translation)
      total_prompt_tokens += tokenizer.encode(system_msg).size
      total_prompt_tokens += tokenizer.encode(prompt).size
    end

    avg_prompt_tokens = sample_entries.size > 0 ? (total_prompt_tokens.to_f / sample_entries.size).ceil : 75
    avg_response_tokens = 25 # Conservative estimate

    {
      avg_prompt_tokens: avg_prompt_tokens,
      input_cost: (sample_entries.size * avg_prompt_tokens / 1000.0) * self.class::GPT4_INPUT_COST_PER_1K,
      output_cost: (sample_entries.size * avg_response_tokens / 1000.0) * self.class::GPT4_OUTPUT_COST_PER_1K
    }
  end

  def calculate_fine_tuning_costs(entries, tokenizer)
    system_msg = "You are an Irish assistant specializing in the Mayo dialect."
    sample_size = [entries.count, 50].min
    sample_entries = entries.limit(sample_size)

    total_example_tokens = 0

    sample_entries.each do |entry|
      # English to Mayo example
      english_prompt = format(PROMPT_TEMPLATES.sample, sentence: entry.translation)
      total_example_tokens += tokenizer.encode(system_msg).size
      total_example_tokens += tokenizer.encode(english_prompt).size
      total_example_tokens += tokenizer.encode(entry.word_or_phrase).size

      # Standard to Mayo example
      if entry.standard_irish.present?
        standard_prompt = "#{entry.standard_irish} (standard Irish)"
        mayo_response = "#{entry.word_or_phrase} (Mayo Irish)"
        total_example_tokens += tokenizer.encode(system_msg).size
        total_example_tokens += tokenizer.encode(standard_prompt).size
        total_example_tokens += tokenizer.encode(mayo_response).size
      end
    end

    avg_tokens_per_example = (total_example_tokens.to_f / (sample_size * 2)).ceil
    total_examples = entries.count * 2
    total_training_tokens = total_examples * avg_tokens_per_example

    {
      avg_tokens_per_example: avg_tokens_per_example,
      total_examples: total_examples,
      total_tokens: total_training_tokens,
      cost: (total_training_tokens / 1000.0) * self.class::GPT35_FINETUNE_COST_PER_1K
    }
  end
end
