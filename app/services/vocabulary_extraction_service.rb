class VocabularyExtractionService
  attr_reader :message_content, :user

  def initialize(message_content, user)
    @message_content = message_content
    @user = user
  end

  def process
    vocabulary_data = extract_vocabulary_from_message
    return nil unless vocabulary_data

    # Create the dictionary entry
    dictionary_entry = user.dictionary_entries.build(
      word_or_phrase: vocabulary_data[:irish],
      translation: vocabulary_data[:translation],
      notes: vocabulary_data[:notes],
      tag_list: vocabulary_data[:tags],
      quality: user.quality || 'low'
    )

    if dictionary_entry.save
      # Generate audio for the new entry
      dictionary_entry.synthesize_text_to_speech_and_store rescue nil
      dictionary_entry
    else
      nil
    end
  end

  private

  def extract_vocabulary_from_message
    # Call OpenAI to extract vocabulary information
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    system_prompt = "You are a helpful assistant that extracts Irish language vocabulary from text. Extract a single Irish word or phrase along with its English translation, notes about usage, and appropriate tags. Format your response as JSON with the following keys: 'irish', 'translation', 'notes', and 'tags' (as an array)."

    user_prompt = "Extract vocabulary information from the following text. If there are multiple Irish phrases, choose the most important or useful one: #{message_content}"

    response = client.chat(
      parameters: {
        model: "gpt-4.1-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        response_format: { type: "json_object" }
      }
    )

    begin
      result = JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
      return result
    rescue => e
      Rails.logger.error("Error parsing vocabulary extraction response: #{e.message}")
      return nil
    end
  end
end
