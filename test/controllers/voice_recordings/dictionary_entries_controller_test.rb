require "test_helper"

class VoiceRecordings::DictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
    # Mock audio snippet creation to avoid file system dependencies in tests
    DictionaryEntry.any_instance.stubs(:create_audio_snippet).returns(true)
  end

  test "should create dictionary_entry" do
    assert_difference('DictionaryEntry.count') do
      @voice_recording = voice_recordings(:one)
      post voice_recording_dictionary_entries_url(@voice_recording), params: { dictionary_entry: { translation: "something", word_or_phrase: "rud éicint", voice_recording_id: @voice_recording.id, region_id: 1, region_start: 4.0, region_end: 10.0 } }
    end

    assert_redirected_to voice_recording_url(@voice_recording)
  end

  test "should create dictionary_entry with new speaker" do
    translation = SecureRandom.alphanumeric
    assert_difference('DictionaryEntry.count') do
      @voice_recording = voice_recordings(:one)
      post voice_recording_dictionary_entries_url(@voice_recording), params: { dictionary_entry: { translation: translation, word_or_phrase: "rud éicint", voice_recording_id: @voice_recording.id, region_id: 1, region_start: 4.0, region_end: 10.0} }
    end

    assert_equal translation, DictionaryEntry.last.translation
    assert_equal "Temporary", DictionaryEntry.last.speaker.name
    assert_redirected_to voice_recording_url(@voice_recording)
  end

  test "should update dictionary_entry via turbo stream" do
    @voice_recording = voice_recordings(:one)
    @entry = dictionary_entries(:with_temp_speaker)

    new_word_or_phrase = "updated word"
    new_translation = "updated translation"

    patch voice_recording_dictionary_entry_url(@voice_recording, @entry),
          params: { dictionary_entry: { word_or_phrase: new_word_or_phrase, translation: new_translation } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type

    @entry.reload
    assert_equal new_word_or_phrase, @entry.word_or_phrase
    assert_equal new_translation, @entry.translation
  end
end
