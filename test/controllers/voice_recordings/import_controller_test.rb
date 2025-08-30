require "test_helper"

class VoiceRecordings::ImportControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one) # teacher
    ApplicationController.any_instance.stubs(:current_user).returns(@user)
  end

  test "should get new" do
    get new_import_url
    assert_response :success
  end

  test "should create voice recording on successful import" do
    # Test should create a placeholder record and queue a job
    assert_difference('VoiceRecording.count', 1) do
      post import_url, params: { url: "https://canuint.ie/test" }
    end
    
    created_recording = VoiceRecording.last
    assert_equal 'pending', created_recording.import_status
    assert_equal @user, created_recording.owner
    assert_redirected_to voice_recording_path(created_recording)
    assert_equal "Import started! Your recording will be available shortly.", flash[:notice]
  end

  test "should handle YouTube URL import" do
    assert_difference('VoiceRecording.count', 1) do
      post import_url, params: { url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
    end
    
    created_recording = VoiceRecording.last
    assert_equal 'pending', created_recording.import_status
    assert_redirected_to voice_recording_path(created_recording)
  end

  test "should handle failed import" do
    # Test should handle validation errors or other failures during placeholder creation
    post import_url, params: { url: "https://unsupported-site.com/test" }
    
    assert_redirected_to new_import_path
    assert_equal "Failed to start import: Unsupported URL. Please use a URL from rte.ie, canuint.ie, or youtube.com", flash[:alert]
  end
end
