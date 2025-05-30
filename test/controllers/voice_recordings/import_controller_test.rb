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
    voice_recording = voice_recordings(:one)
    Importers::CanuintIe.expects(:import).with("https://canuint.ie/test").returns(voice_recording)

    post import_url, params: { url: "https://canuint.ie/test" }
    
    assert_redirected_to voice_recording_path(voice_recording)
    assert_equal "Voice recording imported successfully", flash[:notice]
  end

  test "should handle failed import" do
    Importers::CanuintIe.expects(:import).with("https://canuint.ie/bad").raises(StandardError.new("Import failed"))

    post import_url, params: { url: "https://canuint.ie/bad" }
    
    assert_redirected_to new_import_path
    assert_equal "Failed to import voice recording: Import failed", flash[:alert]
  end
end
