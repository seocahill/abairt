# frozen_string_literal: true

# Dictionary entry as the translation assistant sees it: the Irish word/phrase, its translation
# and the metadata needed to judge and improve that translation (accuracy, quality, dialect,
# speaker, tags, notes). Unlike the public Api::TranscriptionSerializer this exposes drafts
# (unconfirmed) and editorial fields, because the MCP surface is admin-only.
#
# Pass `params: { host: ... }` so audio URLs can be built without a request context.
class Mcp::EntrySerializer
  include Alba::Resource

  attributes :id, :word_or_phrase, :translation, :standard_irish, :notes,
    :region_id, :region_start, :region_end, :voice_recording_id, :updated_at

  attribute :accuracy_status, &:accuracy_status
  attribute :quality, &:quality
  attribute :status, &:status

  attribute :dialect do |entry|
    entry.speaker&.dialect
  end

  attribute :tags do |entry|
    entry.tag_list
  end

  attribute :translator do |entry|
    entry.translator&.name
  end

  attribute :audio_url do |entry, params: {}|
    next nil unless entry.media.attached?

    Rails.application.routes.url_helpers.rails_blob_url(entry.media, host: params[:host])
  rescue
    nil
  end

  one :speaker, resource: Mcp::SpeakerSerializer
end
