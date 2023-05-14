require "application_system_test_case"

class VoiceRecordingsTest < ApplicationSystemTestCase
  setup do
    @voice_recording = voice_recordings(:one)
  end

  test "visiting the index" do
    visit voice_recordings_url
    assert_selector "h1", text: "Voice Recordings"
  end

  test "creating a Voice recording" do
    visit voice_recordings_url
    click_on "New Voice Recording"

    fill_in "Description", with: @voice_recording.description
    fill_in "Title", with: @voice_recording.title
    click_on "Create Voice recording"

    assert_text "Voice recording was successfully created"
    click_on "Back"
  end

  test "updating a Voice recording" do
    visit voice_recordings_url
    click_on "Edit", match: :first

    fill_in "Description", with: @voice_recording.description
    fill_in "Title", with: @voice_recording.title
    click_on "Update Voice recording"

    assert_text "Voice recording was successfully updated"
    click_on "Back"
  end

  test "destroying a Voice recording" do
    visit voice_recordings_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Voice recording was successfully destroyed"
  end
end
