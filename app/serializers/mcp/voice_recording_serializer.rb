# frozen_string_literal: true

# Recording context: the source audio an entry was drawn from, its dialect region and the
# speakers heard in it. Segments are summarised (count + the diarized transcript) rather than
# dumped verbatim so the assistant can research surrounding context without huge payloads.
#
# Pass `params: { host: ... }` so the Active Storage blob URLs can be built without a request
# context.
class Mcp::VoiceRecordingSerializer
  include Alba::Resource

  # Signed Active Storage URL for an attachment, or nil when nothing is attached.
  def self.blob_url(attachment, host)
    return nil unless attachment.attached?

    Rails.application.routes.url_helpers.rails_blob_url(attachment, host: host)
  rescue
    nil
  end

  attributes :id, :title, :description

  attribute :external_id, &:fotheidil_video_id
  attribute :duration_seconds, &:duration_seconds
  attribute :dialect_region, &:dialect_region

  # The original uploaded recording (video or audio).
  attribute :media_url do |recording|
    Mcp::VoiceRecordingSerializer.blob_url(recording.media, params[:host])
  end

  # The extracted/downsampled audio track used for transcription.
  attribute :audio_track_url do |recording|
    Mcp::VoiceRecordingSerializer.blob_url(recording.audio_track, params[:host])
  end

  attribute :entries_count do |recording|
    recording.dictionary_entries_count
  end

  attribute :segments do |recording|
    Array(recording.segments)
  end

  many :users, resource: Mcp::SpeakerSerializer, key: :speakers
end
