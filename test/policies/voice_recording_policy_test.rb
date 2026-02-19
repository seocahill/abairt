require "test_helper"

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

  test "retranscribe? allows admin users" do
    admin = User.new(role: :admin)
    policy = VoiceRecordingPolicy.new(admin, @voice_recording)

    assert policy.retranscribe?
  end

  test "retranscribe? denies non-admin users" do
    assert_not @policy.retranscribe?
  end

  test "retranscribe? denies teacher users" do
    teacher = User.new(role: :teacher)
    policy = VoiceRecordingPolicy.new(teacher, @voice_recording)

    assert_not policy.retranscribe?
  end

  test "retranscribe? denies nil user" do
    policy = VoiceRecordingPolicy.new(nil, @voice_recording)

    assert_not policy.retranscribe?
  end
end
