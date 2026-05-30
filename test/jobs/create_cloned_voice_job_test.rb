# frozen_string_literal: true

require "test_helper"

class CreateClonedVoiceJobTest < ActiveJob::TestCase
  test "calls CreateCloneService for the user" do
    user = users(:four)
    service = mock("VoiceCloning::CreateCloneService")
    service.expects(:call)
    VoiceCloning::CreateCloneService.expects(:new).with(user).returns(service)

    CreateClonedVoiceJob.perform_now(user.id)
  end
end
