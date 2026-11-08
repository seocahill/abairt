# frozen_string_literal: true

# A recording to pick from, without its transcript: fetch that with
# `GET /api/voice_recordings/:id` when it is played.
class Api::RecordingSummarySerializer
  include Alba::Resource

  attributes :id, :title, :duration_seconds

  attribute :dialect_region, &:dialect_region
  attribute :lines_count, &:dictionary_entries_count

  attribute :audio_url do |recording|
    Rails.application.routes.url_helpers.url_for(recording.listening_audio)
  end
end
