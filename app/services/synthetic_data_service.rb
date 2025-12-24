# frozen_string_literal: true

class SyntheticDataService
  def initialize(entry)
    @entry = entry
    @client = openai_client
  end

  def create_synthetic_data
    response = request_standard_irish
    response_data = JSON.parse(response.dig("choices", 0, "message", "content"))
    standard_irish, is_significantly_different = response_data.values_at("standard_irish", "is_significantly_different")

    return if standard_irish.blank?

    if is_significantly_different
      entry.update_columns(standard_irish: standard_irish)
    else
      entry.update_columns(standard_irish: "not_for_training")
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse response for entry #{entry.id}: #{e.message}")
    Sentry.capture_exception(e)
    false
  end

  private

  attr_reader :entry, :client

  def openai_client
    @openai_client ||= OpenAI::Client.new(access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org))
  end

  def request_standard_irish
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

    client.chat(
      parameters: {
        model: "gpt-4.1",
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
end
