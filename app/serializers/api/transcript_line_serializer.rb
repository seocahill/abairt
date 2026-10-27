# frozen_string_literal: true

# One line of a recording's transcript, timed in seconds from the start. A
# placeholder speaker from diarization (a temporary user) is left out.
class Api::TranscriptLineSerializer
  include Alba::Resource

  attributes :id, :translation

  attribute :irish, &:word_or_phrase
  attribute(:start) { |entry| entry.region_start.to_f }
  attribute(:end) { |entry| entry.region_end.to_f }

  attribute :speaker do |entry|
    Api::SpeakerSerializer.new(entry.speaker).serializable_hash unless entry.speaker.nil? || entry.speaker.temporary?
  end
end
