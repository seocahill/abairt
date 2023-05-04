class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_many :conversations
  has_many :users, through: :speakers
  has_many :dictionary_entries

  def percentage_complete
    rand(99).to_s + "%"
  end
end
