# frozen_string_literal: true

# MCP tool: list the most recently updated confirmed transcriptions.
class ListRecentTranscriptionsTool < MCP::Tool
  tool_name "list_recent_transcriptions"
  description "List the most recently updated confirmed transcriptions from the abairt " \
              "corpus, newest first."
  input_schema(
    properties: {
      limit: {
        type: "integer",
        description: "Maximum number of transcriptions to return (default 20, max 50)"
      }
    },
    required: []
  )

  class << self
    def call(server_context:, limit: 20)
      limit = limit.to_i.clamp(1, 50)

      records = DictionaryEntry.confirmed_accuracy
        .includes(:speaker, :tags)
        .order(updated_at: :desc)
        .limit(limit)

      entries = records.map { |entry| summarise(entry) }

      MCP::Tool::Response.new([{
        type: "text",
        text: JSON.pretty_generate(count: entries.size, entries: entries)
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
        updated_at: entry.updated_at.iso8601
      }
    end
  end
end
