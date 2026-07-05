# frozen_string_literal: true

# Full detail for a single entry: everything in Mcp::EntrySerializer plus the recording context
# it came from and its translation/accuracy history (PaperTrail), so the assistant can research
# how a phrase has been rendered before and by whom.
class Mcp::EntryDetailSerializer < Mcp::EntrySerializer
  one :voice_recording, resource: Mcp::VoiceRecordingSerializer

  attribute :history do |entry|
    entry.versions.reorder(created_at: :desc).map do |version|
      {
        event: version.event,
        whodunnit: version.whodunnit,
        changed_at: version.created_at&.iso8601,
        changes: (version.changeset if version.respond_to?(:changeset))
      }.compact
    rescue
      {event: version.event, changed_at: version.created_at&.iso8601}
    end
  end
end
