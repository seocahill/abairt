# frozen_string_literal: true

# A single person's context plus a sample of their recent entries - so the assistant can ground a
# translation in the same speaker's other phrasings and dialect.
class GetSpeakerTool < ApplicationTool
  tool_name "get_speaker"
  description "Fetch a user by id with their dialect/role and a sample of their most recent " \
              "spoken entries."
  input_schema(
    properties: {
      id: {type: "integer", description: "The user id"},
      entries_limit: {type: "integer", description: "How many recent entries to include (default 20, max 50)"}
    },
    required: ["id"]
  )

  def self.call(id:, server_context:, entries_limit: 20)
    guard do
      user = User.find(id)
      recent = user.dictionary_entries
        .includes(:speaker, :translator, :tags, :voice_recording)
        .order(updated_at: :desc)
        .limit(entries_limit.to_i.clamp(1, 50))

      ok(
        speaker: Mcp::SpeakerSerializer.new(user).serializable_hash,
        recent_entries: Mcp::EntrySerializer.new(recent, params: {host: host(server_context)}).serializable_hash
      )
    end
  end
end
