require "test_helper"

class VoiceRecordings::SpeakersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @voice_recording = voice_recordings(:one)
    @owner = @voice_recording.owner
    ApplicationController.any_instance.stubs(:current_user).returns(@owner)
    Current.user = @owner
  end

  test "updates temporary speaker to existing speaker" do
    temp_speaker = users(:temporary)
    existing_speaker = users(:five)
    entry = dictionary_entries(:with_temp_speaker)

    patch voice_recording_speaker_url(@voice_recording, temp_speaker), params: {
      speaker_id: existing_speaker.id
    }

    assert_redirected_to voice_recording_speakers_path(@voice_recording)

    # Check that entries were transferred
    entry.reload
    assert_equal existing_speaker, entry.speaker

    # Check that temporary speaker still exists but has no entries
    temp_speaker.reload
    assert_equal 0, temp_speaker.dictionary_entries.count
  end

  test "only voice recording owner can manage speakers" do
    ApplicationController.any_instance.stubs(:current_user).returns(users(:two))  # Not the owner

    get voice_recording_speakers_url(@voice_recording)
    assert_redirected_to root_url
  end

  test "lists only temporary speakers for this recording" do
    # Create temp speaker with entries in this recording
    temp_speaker1 = User.create!(
      name: "SPEAKER_01",
      email: "speaker_01@temporary.abairt",
      role: :temporary
    )

    # Create temp speaker with entries in another recording
    temp_speaker2 = User.create!(
      name: "SPEAKER_02",
      email: "speaker_02@temporary.abairt",
      role: :temporary
    )

    entry1 = dictionary_entries(:one)
    entry1.update!(speaker: temp_speaker1, voice_recording: @voice_recording)

    entry2 = dictionary_entries(:two)
    entry2.update!(speaker: temp_speaker2, voice_recording: voice_recordings(:two))

    get voice_recording_speakers_url(@voice_recording)
    assert_response :success
    # with_html_page do
      assert_select 'div.temp-speaker-entry' do |elements|
        assert_equal 1, elements.count
        assert_match temp_speaker1.name, elements.first.text
        assert_no_match temp_speaker2.name, elements.first.text
      end
    # end
  end

  test "temporary users are filtered from general user lists" do
    temp_user = User.create!(
      name: "TEMP_USER",
      email: "temp@temporary.abairt",
      role: :temporary
    )

    get users_url
    assert_response :success
    assert_no_match temp_user.name, @response.body
  end
end
