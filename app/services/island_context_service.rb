# frozen_string_literal: true

# Given an English island description from the Caotharnach app, finds relevant
# dictionary entries (with audio) using a hybrid search:
#   1. LLM keyword extraction → FTS5 search on the translation field
#   2. Vector similarity search (sqlite-vec) on the full island description
#
# Results are merged: FTS matches first (keyword precision), then any additional
# entries surfaced by vector search that weren't caught by keywords.
#
# Usage:
#   IslandContextService.new("ordering coffee in a café...").call
class IslandContextService
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 50
  MAX_KEYWORDS = 12

  def initialize(description, limit: DEFAULT_LIMIT)
    @description = description
    @limit = [limit.to_i, MAX_LIMIT].min
  end

  def call
    fts_results = fts_search(extract_keywords)
    vector_results = vector_search

    merge(fts_results, vector_results)
  end

  private

  # ── FTS ──────────────────────────────────────────────────────────────────

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
            Return ONLY valid JSON: {"keywords": ["word1", "phrase2", ...]}
          PROMPT
        },
        { role: "user", content: @description }
      ],
      temperature: 0.2,
      response_format: { type: "json_object" }
    })

    parsed = JSON.parse(response.dig("choices", 0, "message", "content"))
    keywords = parsed["keywords"] || parsed.values.first
    Array(keywords).map(&:to_s).reject(&:blank?).first(MAX_KEYWORDS)
  rescue => e
    Rails.logger.error("IslandContextService keyword extraction failed: #{e.message}")
    []
  end

  def fts_search(keywords)
    return [] if keywords.empty?

    fts_query = keywords.map { |k| "\"#{k.gsub('"', '')}\"" }.join(" OR ")

    DictionaryEntry
      .has_recording
      .joins(:fts_dictionary_entries)
      .where("fts_dictionary_entries MATCH ?", fts_query)
      .with_attached_media
      .includes(:speaker, :voice_recording)
      .distinct
      .order("rank")
      .limit(@limit)
      .to_a
  rescue => e
    Rails.logger.error("IslandContextService FTS search failed: #{e.message}")
    []
  end

  # ── Vector ───────────────────────────────────────────────────────────────

  def vector_search
    EmbeddingService.new
      .search(@description, limit: @limit)
      .then { |entries| filter_to_with_audio(entries) }
  rescue => e
    Rails.logger.error("IslandContextService vector search failed: #{e.message}")
    []
  end

  def filter_to_with_audio(entries)
    return [] if entries.empty?

    with_audio_ids = DictionaryEntry
      .has_recording
      .where(id: entries.map(&:id))
      .pluck(:id)
      .to_set

    entries.select { |e| with_audio_ids.include?(e.id) }
  end

  # ── Merge ─────────────────────────────────────────────────────────────────

  # FTS results first (explicit keyword matches), then vector-only results,
  # capped at @limit total.
  def merge(fts_results, vector_results)
    fts_ids = fts_results.map(&:id).to_set
    extra = vector_results.reject { |e| fts_ids.include?(e.id) }
    (fts_results + extra).first(@limit)
  end
end
