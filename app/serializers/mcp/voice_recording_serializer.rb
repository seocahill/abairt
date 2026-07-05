# frozen_string_literal: true

# Recording context: the source audio an entry was drawn from, its dialect region and the
# speakers heard in it. Segments are summarised (count + the diarized transcript) rather than
# dumped verbatim so the assistant can research surrounding context without huge payloads.
class Mcp::VoiceRecordingSerializer
  include Alba::Resource

  attributes :id, :title, :description

  attribute :external_id, &:fotheidil_video_id
  attribute :duration_seconds, &:duration_seconds
  attribute :dialect_region, &:dialect_region

  attribute :entries_count do |recording|
    recording.dictionary_entries_count
  end

  attribute :segments do |recording|
    Array(recording.segments)
  end

  many :users, resource: Mcp::SpeakerSerializer, key: :speakers
end
