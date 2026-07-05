# frozen_string_literal: true

# Full-text search across the whole corpus (confirmed and draft), with optional filters, so the
# assistant can find prior translations, related phrasings and a speaker's other entries.
class SearchDictionaryEntriesTool < ApplicationTool
  tool_name "search_dictionary_entries"
  description "Search the abairt Irish-language corpus (confirmed and unconfirmed) for entries " \
              "matching a query in Irish or English. Optionally filter by dialect, speaker, tag, " \
              "accuracy status or whether audio is attached."
  input_schema(
    properties: {
      query: {type: "string", description: "Search text in Irish or English"},
      dialect: {type: "string", description: "Filter by speaker dialect, e.g. acaill, lár_chonnachta"},
      speaker_id: {type: "integer", description: "Filter to entries spoken by this user id"},
      tag: {type: "string", description: "Filter to entries carrying this tag"},
      accuracy_status: {type: "string", enum: %w[confirmed unconfirmed], description: "Filter by accuracy status"},
      has_audio: {type: "boolean", description: "Only entries with (true) or without (false) attached audio"},
      limit: {type: "integer", description: "Max results (default 20, max 50)"}
    },
    required: ["query"]
  )

  def self.call(query:, server_context:, dialect: nil, speaker_id: nil, tag: nil,
    accuracy_status: nil, has_audio: nil, limit: 20)
    guard do
      records = DictionaryEntry
        .joins(:fts_dictionary_entries)
        .where("fts_dictionary_entries match ?", query)
        .includes(:speaker, :translator, :tags, :voice_recording)
        .distinct
        .order("rank")
        .limit(limit.to_i.clamp(1, 50))

      records = records.joins(:speaker).where(users: {dialect: dialect}) if dialect.present?
      records = records.where(speaker_id: speaker_id) if speaker_id
      records = records.tagged_with(tag) if tag.present?
      records = records.where(accuracy_status: accuracy_status) if accuracy_status.present?
      records = records.has_recording if has_audio == true
      records = records.where.missing(:media_attachment) if has_audio == false

      entries = Mcp::EntrySerializer.new(records, params: {host: host(server_context)}).serializable_hash

      ok(query: query, count: entries.size, entries: entries)
    rescue ActiveRecord::StatementInvalid
      error("Could not run the search - the query contains characters the full-text search " \
            "cannot parse. Try simpler search terms.")
    end
  end
end
