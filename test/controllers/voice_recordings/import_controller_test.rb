require "test_helper"

class VoiceRecordings::ImportControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get voice_recordings_import_new_url
    assert_response :success
  end

  test "should get create" do
    get voice_recordings_import_create_url
    assert_response :success
  end
end
