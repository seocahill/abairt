class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :voice_recording
end
