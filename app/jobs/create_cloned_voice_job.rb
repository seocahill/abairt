# frozen_string_literal: true

class CreateClonedVoiceJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    VoiceCloning::CreateCloneService.new(user).call
  end
end
