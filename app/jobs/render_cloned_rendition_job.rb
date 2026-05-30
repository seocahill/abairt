# frozen_string_literal: true

class RenderClonedRenditionJob < ApplicationJob
  queue_as :default

  def perform(rendition_id)
    rendition = ClonedAudioRendition.find(rendition_id)
    VoiceCloning::RenderRenditionService.new(rendition).call
  end
end
