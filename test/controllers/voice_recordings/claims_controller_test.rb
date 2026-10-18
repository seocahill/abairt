require "test_helper"

class VoiceRecordings::ClaimsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @voice_recording = voice_recordings(:one)
    # users(:one) is a teacher: whoever may confirm an entry may take a
    # recording to check through.
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "taking a recording to check through" do
    post voice_recording_claim_url(@voice_recording)

    assert_equal users(:one), @voice_recording.reload.claimed_by
    assert_redirected_to voice_recording_url(@voice_recording)
  end

  test "says who has it rather than taking it from them" do
    @voice_recording.claim(users(:two))

    post voice_recording_claim_url(@voice_recording)

    assert_equal users(:two), @voice_recording.reload.claimed_by
    assert_match users(:two).name, flash[:alert]
  end

  test "handing a recording back frees it" do
    @voice_recording.claim(users(:one))

    delete voice_recording_claim_url(@voice_recording)

    assert_nil @voice_recording.reload.claimed_by
  end

  test "somebody else's claim is not yours to release" do
    @voice_recording.claim(users(:two))

    delete voice_recording_claim_url(@voice_recording)

    assert_equal users(:two), @voice_recording.reload.claimed_by
  end

  test "an admin can free a claim somebody never got back to" do
    @voice_recording.claim(users(:two))
    ApplicationController.any_instance.stubs(:current_user).returns(users(:admin))

    delete voice_recording_claim_url(@voice_recording)

    assert_nil @voice_recording.reload.claimed_by
  end
end
