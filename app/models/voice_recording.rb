class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_many :conversations
  has_many :users, through: :speakers
end
