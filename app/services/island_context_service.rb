# frozen_string_literal: true

# Given an English island description from the Caotharnach app, finds relevant
# confirmed Mayo dialect dictionary entries (with audio) using LLM keyword
# extraction + FTS5 search on the translation field.
class IslandContextService
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 50
  MAX_KEYWORDS = 12

  def initialize(description, limit: DEFAULT_LIMIT)
    @description = description
    @limit = [limit.to_i, MAX_LIMIT].min
  end

  def call
    keywords = extract_keywords
    return [] if keywords.empty?

    search_with_keywords(keywords)
  end

  private

  def extract_keywords
    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.dig(:openai, :openai_key),
      organization_id: Rails.application.credentials.dig(:openai, :openai_org)
    )

    response = client.chat(parameters: {
      model: "gpt-4.1",
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You extract English search terms from scenario descriptions for an Irish language learning app.
            Return 8-12 short, distinct English words or short phrases (1-3 words each) that would
            commonly appear in English translations of Irish phrases relevant to this scenario.
            Focus on vocabulary, actions, and common expressions for the described context.
            Return ONLY valid JSON in this exact format: {"keywords": ["word1", "phrase2", ...]}
          PROMPT
        },
        { role: "user", content: @description }
      ],
      temperature: 0.2,
      response_format: { type: "json_object" }
    })

    content = response.dig("choices", 0, "message", "content")
    parsed = JSON.parse(content)
    keywords = parsed["keywords"] || parsed.values.first
    Array(keywords).map(&:to_s).reject(&:blank?).first(MAX_KEYWORDS)
  rescue => e
    Rails.logger.error("IslandContextService keyword extraction failed: #{e.message}")
    []
  end

  def search_with_keywords(keywords)
    # Build FTS5 OR query - wrap multi-word phrases in quotes for phrase matching
    fts_query = keywords.map { |k| "\"#{k.gsub('"', '')}\"" }.join(" OR ")

    DictionaryEntry
      .confirmed_accuracy
      .mayo_dialect
      .has_recording
      .joins(:fts_dictionary_entries)
      .where("fts_dictionary_entries MATCH ?", fts_query)
      .with_attached_media
      .includes(:speaker, :voice_recording)
      .distinct
      .order("rank")
      .limit(@limit)
  rescue => e
    Rails.logger.error("IslandContextService search failed: #{e.message}")
    []
  end
end
