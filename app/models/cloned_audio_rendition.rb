# frozen_string_literal: true

class ClonedAudioRendition < ApplicationRecord
  belongs_to :voice_user, class_name: "User"
  belongs_to :source, polymorphic: true

  has_one_attached :media

  enum :status, {pending: 0, ready: 1, failed: 2}

  validates :voice_user_id,
    uniqueness: {scope: [:source_type, :source_id]}

  validate :voice_user_must_have_cloned_voice

  scope :for_source, ->(source) { where(source: source) }

  private

  def voice_user_must_have_cloned_voice
    return if voice_user&.cloned_voice_id.present?

    errors.add(:voice_user, "must have a cloned voice")
  end
end
