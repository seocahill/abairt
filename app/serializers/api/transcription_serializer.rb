# frozen_string_literal: true

class Api::TranscriptionSerializer
  include Alba::Resource

  attributes :id, :word_or_phrase, :translation, :region_id, :region_start, :region_end, :updated_at

  attribute :audio_url do |entry, params: {}|
    entry.media_url
  end

  one :speaker, resource: Api::SpeakerSerializer
  one :voice_recording, resource: Api::VoiceRecordingSerializer
end

