require "test_helper"

class VoiceRecordings::DictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get voice_recordings_dictionary_entries_create_url
    assert_response :success
  end
end
