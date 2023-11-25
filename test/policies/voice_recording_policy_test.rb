require 'test_helper'

class VoiceRecordingPolicyTest < ActiveSupport::TestCase
  def setup
    @user = User.new
    @voice_recording = VoiceRecording.new(owner: @user)
    @policy = VoiceRecordingPolicy.new(@user, @voice_recording)
  end

  test "edit? allows destruction when user is the owner" do
    assert @policy.edit?
  end

  test "edit? does not allow destruction when user is not the owner" do
    other_user = User.new
    @voice_recording.owner = other_user

    assert_not @policy.edit?
  end

  test "destroy? allows destruction when user is the owner" do
    assert @policy.destroy?
  end

  test "destroy? does not allow destruction when user is not the owner" do
    other_user = User.new
    @voice_recording.owner = other_user

    assert_not @policy.destroy?
  end
end
