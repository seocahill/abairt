# frozen_string_literal: true

class VoiceRecordingLocation < ApplicationRecord
  belongs_to :voice_recording
  belongs_to :location

  validates :voice_recording_id, uniqueness: {scope: :location_id}
  validates :confidence, inclusion: {in: %w[high medium low]}

  scope :high_confidence, -> { where(confidence: "high") }
  scope :by_confidence, -> { order(Arel.sql("CASE confidence WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END")) }
end
