# frozen_string_literal: true

# List recently updated entries, newest first, optionally filtered - useful for reviewing the
# latest drafts awaiting translation or confirmation.
class ListRecentTranscriptionsTool < ApplicationTool
  tool_name "list_recent_transcriptions"
  description "List the most recently updated entries from the abairt corpus, newest first. " \
              "Optionally filter by accuracy status or dialect."
  input_schema(
    properties: {
      accuracy_status: {type: "string", enum: %w[confirmed unconfirmed], description: "Filter by accuracy status"},
      dialect: {type: "string", description: "Filter by speaker dialect"},
      limit: {type: "integer", description: "Max results (default 20, max 50)"}
    },
    required: []
  )

  def self.call(server_context:, accuracy_status: nil, dialect: nil, limit: 20)
    guard do
      records = DictionaryEntry
        .includes(:speaker, :translator, :tags, :voice_recording)
        .order(updated_at: :desc)
        .limit(limit.to_i.clamp(1, 50))

      records = records.where(accuracy_status: accuracy_status) if accuracy_status.present?
      records = records.joins(:speaker).where(users: {dialect: dialect}) if dialect.present?

      entries = Mcp::EntrySerializer.new(records, params: {host: host(server_context)}).serializable_hash

      ok(count: entries.size, entries: entries)
    end
  end
end
