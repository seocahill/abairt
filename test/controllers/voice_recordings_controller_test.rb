require "test_helper"

class VoiceRecordingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @voice_recording = voice_recordings(:one)
  end

  test "should get index" do
    get voice_recordings_url
    assert_response :success
  end

  test "should get new" do
    get new_voice_recording_url
    assert_response :success
  end

  test "should create voice_recording" do
    assert_difference('VoiceRecording.count') do
      post voice_recordings_url, params: { voice_recording: { description: @voice_recording.description, title: @voice_recording.title } }
    end

    assert_redirected_to voice_recording_url(VoiceRecording.last)
  end

  test "should show voice_recording" do
    get voice_recording_url(@voice_recording)
    assert_response :success
  end

  test "should get edit" do
    get edit_voice_recording_url(@voice_recording)
    assert_response :success
  end

  test "should update voice_recording" do
    patch voice_recording_url(@voice_recording), params: { voice_recording: { description: @voice_recording.description, title: @voice_recording.title } }
    assert_redirected_to voice_recording_url(@voice_recording)
  end

  test "should destroy voice_recording" do
    assert_difference('VoiceRecording.count', -1) do
      delete voice_recording_url(@voice_recording)
    end

    assert_redirected_to voice_recordings_url
  end
end
