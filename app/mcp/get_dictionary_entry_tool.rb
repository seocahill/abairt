# frozen_string_literal: true

# Fetch a single entry in full detail: translation, dialect/speaker context, the recording it
# came from, and its translation/accuracy history.
class GetDictionaryEntryTool < ApplicationTool
  tool_name "get_dictionary_entry"
  description "Fetch a single abairt dictionary entry by id in full detail: translation, dialect, " \
              "speaker, tags, audio, the source recording and its edit history."
  input_schema(
    properties: {id: {type: "integer", description: "The dictionary entry id"}},
    required: ["id"]
  )

  def self.call(id:, server_context:)
    guard do
      entry = DictionaryEntry
        .includes(
          :speaker, :translator, :tags, :versions,
          {media_attachment: :blob},
          {voice_recording: [:users, {media_attachment: :blob}, {audio_track_attachment: :blob}]}
        )
        .find(id)

      ok(Mcp::EntryDetailSerializer.new(entry, params: {host: host(server_context)}).serializable_hash)
    end
  end
end
