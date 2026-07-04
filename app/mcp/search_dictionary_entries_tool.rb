# frozen_string_literal: true

# MCP tool: full-text search over confirmed abairt dictionary entries.
class SearchDictionaryEntriesTool < MCP::Tool
  tool_name "search_dictionary_entries"
  description "Search the abairt Irish-language dictionary for confirmed entries matching a " \
              "query. Matches Irish words/phrases and their English translations."
  input_schema(
    properties: {
      query: {
        type: "string",
        description: "Search text in Irish or English"
      },
      limit: {
        type: "integer",
        description: "Maximum number of results to return (default 20, max 50)"
      }
    },
    required: ["query"]
  )

  class << self
    def call(query:, server_context:, limit: 20)
      limit = limit.to_i.clamp(1, 50)

      records = DictionaryEntry.confirmed_accuracy
        .joins(:fts_dictionary_entries)
        .where("fts_dictionary_entries match ?", query)
        .distinct
        .order("rank")
        .limit(limit)
        .includes(:speaker, :tags)

      entries = records.map { |entry| summarise(entry) }

      MCP::Tool::Response.new([{
        type: "text",
        text: JSON.pretty_generate(query: query, count: entries.size, entries: entries)
      }])
    rescue ActiveRecord::StatementInvalid
      MCP::Tool::Response.new([{
        type: "text",
        text: "Could not run the search - the query contains characters the full-text " \
              "search cannot parse. Try simpler search terms."
      }])
    end

    private

    def summarise(entry)
      {
        id: entry.id,
        word_or_phrase: entry.word_or_phrase,
        translation: entry.translation,
        dialect: entry.speaker&.dialect,
        has_audio: entry.media.attached?,
        tags: entry.tag_list
      }
    end
  end
end
