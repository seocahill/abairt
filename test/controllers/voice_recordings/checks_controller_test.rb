require "test_helper"

class VoiceRecordings::ChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @recording = voice_recordings(:one)
    @recording.dictionary_entries.destroy_all
    @first, @second = [1, 2].map do |n|
      DictionaryEntry.create!(voice_recording: @recording, speaker: users(:one), owner: users(:one),
        word_or_phrase: "line #{n}", translation: "t#{n}", region_start: n, region_end: n + 1)
    end
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
    Flipper.enable(:f140_check_mode)
  end

  test "is not there with the flag off" do
    Flipper.disable(:f140_check_mode)
    get voice_recording_check_url(@recording)
    assert_response :not_found
  end

  test "shows the first unchecked line and what is left" do
    get voice_recording_check_url(@recording)
    assert_response :success
    assert_select "textarea[name='dictionary_entry[word_or_phrase]']", text: /line 1/
    assert_select "[data-testid=check-count]", "2 of 2 left"
    assert_select "input[type=submit][value='Confirm and next']"
  end

  test "confirm and next saves, confirms and moves on" do
    patch voice_recording_check_url(@recording, entry_id: @first.id),
      params: {dictionary_entry: {word_or_phrase: "fixed", translation: "t1"}}

    assert_redirected_to voice_recording_check_url(@recording, entry_id: @second.id)
    @first.reload
    assert @first.confirmed?
    assert_equal "fixed", @first.word_or_phrase
    assert_equal users(:one), @first.translator
  end

  test "says so when every line is checked" do
    @second.update!(accuracy_status: :confirmed)
    patch voice_recording_check_url(@recording, entry_id: @first.id),
      params: {dictionary_entry: {word_or_phrase: "x"}}
    follow_redirect!
    assert_select "p", /Every line in this recording has been checked/
  end

  test "a checked line stays locked" do
    @first.update!(accuracy_status: :confirmed)
    patch voice_recording_check_url(@recording, entry_id: @first.id),
      params: {dictionary_entry: {word_or_phrase: "changed"}}
    assert_redirected_to voice_recording_check_url(@recording)
    assert_equal "line 1", @first.reload.word_or_phrase
  end

  test "a student cannot confirm" do
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one).tap { |u| u.role = :student })
    patch voice_recording_check_url(@recording, entry_id: @first.id),
      params: {dictionary_entry: {word_or_phrase: "x"}}
    assert @first.reload.unconfirmed?
    get voice_recording_check_url(@recording)
    assert_response :redirect
  end

  test "the recording page offers Check only with the flag on" do
    get voice_recording_url(@recording)
    assert_select "a[href=?]", voice_recording_check_path(@recording)
    Flipper.disable(:f140_check_mode)
    get voice_recording_url(@recording)
    assert_select "a[href=?]", voice_recording_check_path(@recording), false
  end

  test "update is not there with the flag off" do
    Flipper.disable(:f140_check_mode)
    patch voice_recording_check_url(@recording, entry_id: @first.id), params: {dictionary_entry: {word_or_phrase: "x"}}
    assert_response :not_found
    assert @first.reload.unconfirmed?
  end

  test "keeps a version of the original text when a line is confirmed" do
    assert_difference -> { @first.versions.count }, 2 do
      patch voice_recording_check_url(@recording, entry_id: @first.id), params: {dictionary_entry: {word_or_phrase: "fixed"}}
    end
    assert_equal "line 1", @first.versions.first.reify.word_or_phrase
  end
end
