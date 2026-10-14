# frozen_string_literal: true

# Speaker / user context for the translation assistant: who said or owns an entry, and the
# dialect + ability that inform how it should be translated. Admin-only surface (see McpController),
# so it deliberately omits contact details like email.
class Mcp::SpeakerSerializer
  include Alba::Resource

  attributes :id, :name, :dialect, :role, :ability
end
