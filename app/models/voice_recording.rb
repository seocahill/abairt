class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_many :conversations, dependent: :destroy
  has_many :users, through: :conversations
  has_many :dictionary_entries

  accepts_nested_attributes_for :conversations

  acts_as_taggable_on :tags

  def meeting_id
    SecureRandom.uuid
  end
end
