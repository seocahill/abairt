# frozen_string_literal: true

# Fetch a recording with its diarized segments, dialect region, speakers heard, and the entries
# drawn from it - the surrounding context for translating any one of those entries.
class GetVoiceRecordingTool < ApplicationTool
  tool_name "get_voice_recording"
  description "Fetch a voice recording by id with its segments, dialect region, speakers and the " \
              "dictionary entries drawn from it."
  input_schema(
    properties: {id: {type: "integer", description: "The voice recording id"}},
    required: ["id"]
  )

  def self.call(id:, server_context:)
    guard do
      recording = VoiceRecording
        .with_attached_media
        .with_attached_audio_track
        .includes(:users, dictionary_entries: [:speaker, :translator, :tags, {media_attachment: :blob}])
        .find(id)
      params = {host: host(server_context)}

      ok(
        recording: Mcp::VoiceRecordingSerializer.new(recording, params: params).serializable_hash,
        entries: Mcp::EntrySerializer.new(recording.dictionary_entries, params: params).serializable_hash
      )
    end
  end
end
