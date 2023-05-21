require "test_helper"

class VoiceRecordings::DictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "should create dictionary_entry" do
    assert_difference('DictionaryEntry.count') do
      @voice_recording = voice_recordings(:one)
      post voice_recording_dictionary_entries_url(@voice_recording), params: { dictionary_entry: { translation: "something", word_or_phrase: "rud éicint", voice_recording_id: @voice_recording.id, region_id: 1, region_start: 4.0, region_end: 10.0 } }
    end

    assert_redirected_to voice_recording_url(@voice_recording)
  end
end
