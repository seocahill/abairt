# frozen_string_literal: true

require "test_helper"

class RenderClonedRenditionJobTest < ActiveJob::TestCase
  test "calls RenderRenditionService for the rendition" do
    user = users(:one)
    user.update!(cloned_voice_id: "voice_abc", voice_clone_status: :ready)
    rendition = ClonedAudioRendition.create!(voice_user: user, source: dictionary_entries(:two))

    service = mock("VoiceCloning::RenderRenditionService")
    service.expects(:call)
    VoiceCloning::RenderRenditionService.expects(:new).with(rendition).returns(service)

    RenderClonedRenditionJob.perform_now(rendition.id)
  end
end
