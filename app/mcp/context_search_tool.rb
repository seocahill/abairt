# frozen_string_literal: true

# Semantic / hybrid search: given a natural-language English description of a situation or
# meaning, find related entries via keyword + vector similarity. Useful when the assistant knows
# what something means but not the exact Irish wording.
class ContextSearchTool < ApplicationTool
  tool_name "context_search"
  description "Find dictionary entries related to an English description of a situation or " \
              "meaning, using hybrid keyword + vector similarity search over the corpus."
  input_schema(
    properties: {
      description: {type: "string", description: "An English description of the meaning or scenario"},
      limit: {type: "integer", description: "Max results (default 20, max 50)"}
    },
    required: ["description"]
  )

  def self.call(description:, server_context:, limit: 20)
    guard do
      records = IslandContextService.new(description, limit: limit).call
      entries = Mcp::EntrySerializer.new(records, params: {host: host(server_context)}).serializable_hash

      ok(description: description, count: entries.size, entries: entries)
    end
  end
end
