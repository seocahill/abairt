# frozen_string_literal: true

# MCP tool: fetch a single confirmed abairt dictionary entry with full detail.
class GetDictionaryEntryTool < MCP::Tool
  tool_name "get_dictionary_entry"
  description "Fetch a single confirmed abairt dictionary entry by id, including its " \
              "translation, dialect, speaker and audio URL when available."
  input_schema(
    properties: {
      id: {
        type: "integer",
        description: "The dictionary entry id"
      }
    },
    required: ["id"]
  )

  class << self
    def call(id:, server_context:)
      entry = DictionaryEntry.confirmed_accuracy
        .includes(:speaker, :voice_recording, :tags)
        .find_by(id: id)

      unless entry
        return MCP::Tool::Response.new([{
          type: "text",
          text: "No confirmed dictionary entry found for id #{id}."
        }])
      end

      MCP::Tool::Response.new([{
        type: "text",
        text: JSON.pretty_generate(detail(entry, server_context[:host]))
      }])
    end

    private

    def detail(entry, host)
      {
        id: entry.id,
        word_or_phrase: entry.word_or_phrase,
        translation: entry.translation,
        dialect: entry.speaker&.dialect,
        speaker: entry.speaker&.name,
        tags: entry.tag_list,
        voice_recording_id: entry.voice_recording_id,
        audio_url: audio_url(entry, host),
        updated_at: entry.updated_at.iso8601
      }
    end

    def audio_url(entry, host)
      return nil unless entry.media.attached?

      Rails.application.routes.url_helpers.rails_blob_url(entry.media, host: host)
    rescue
      nil
    end
  end
end
