# frozen_string_literal: true

# A recording to listen to, with its confirmed transcript in order. Pass the
# lines as `params: { lines: recording.transcript_lines }`.
class Api::RecordingTranscriptSerializer
  include Alba::Resource

  attributes :id, :title, :duration_seconds

  attribute :dialect_region, &:dialect_region

  attribute :audio_url do |recording|
    Rails.application.routes.url_helpers.url_for(recording.listening_audio)
  end

  attribute :lines do |_recording|
    Api::TranscriptLineSerializer.new(params[:lines]).serializable_hash
  end
end
