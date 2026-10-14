# frozen_string_literal: true

# Browse recordings, newest first, optionally filtered by title/description text.
class ListVoiceRecordingsTool < ApplicationTool
  tool_name "list_voice_recordings"
  description "List voice recordings in the corpus, newest first. Optionally filter by a text " \
              "query matched against title and description."
  input_schema(
    properties: {
      query: {type: "string", description: "Optional text to match against title/description"},
      limit: {type: "integer", description: "Max results (default 20, max 50)"}
    },
    required: []
  )

  def self.call(server_context:, query: nil, limit: 20)
    guard do
      records = VoiceRecording
        .with_attached_media
        .with_attached_audio_track
        .includes(:users)
        .order(created_at: :desc)
        .limit(limit.to_i.clamp(1, 50))
      if query.present?
        like = "%#{query}%"
        records = records.where("title LIKE ? OR description LIKE ?", like, like)
      end

      recordings = Mcp::VoiceRecordingSerializer.new(records, params: {host: host(server_context)}).serializable_hash
      ok(count: recordings.size, recordings: recordings)
    end
  end
end
