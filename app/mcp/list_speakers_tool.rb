# frozen_string_literal: true

# List people in the corpus (speakers, translators, teachers) with their dialect - context for
# who produced an entry and how their dialect shapes it.
class ListSpeakersTool < ApplicationTool
  tool_name "list_speakers"
  description "List users in the corpus with their dialect and role. Optionally filter by dialect, " \
              "role or a name search."
  input_schema(
    properties: {
      query: {type: "string", description: "Optional name search"},
      dialect: {type: "string", description: "Filter by dialect"},
      role: {type: "string", description: "Filter by role, e.g. speaker, translator, teacher, admin"},
      limit: {type: "integer", description: "Max results (default 30, max 100)"}
    },
    required: []
  )

  def self.call(server_context:, query: nil, dialect: nil, role: nil, limit: 30)
    guard do
      users = User.active.order(:name).limit(limit.to_i.clamp(1, 100))
      users = users.search(query) if query.present? && User.respond_to?(:search)
      users = users.where(dialect: dialect) if dialect.present?
      users = users.by_role(role) if role.present?

      speakers = Mcp::SpeakerSerializer.new(users).serializable_hash
      ok(count: speakers.size, speakers: speakers)
    end
  end
end
