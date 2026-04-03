require "test_helper"

class VoiceRecordingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @voice_recording = voice_recordings(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
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
    assert_difference("VoiceRecording.count") do
      post voice_recordings_url, params: {voice_recording: {description: @voice_recording.description, title: @voice_recording.title}}
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
    patch voice_recording_url(@voice_recording), params: {voice_recording: {description: @voice_recording.description, title: @voice_recording.title}}
    assert_redirected_to voice_recording_url(@voice_recording)
  end

  test "should destroy voice_recording" do
    assert_difference("VoiceRecording.count", -1) do
      delete voice_recording_url(@voice_recording)
    end

    assert_redirected_to voice_recordings_url
  end

  test "retranscribe creates duplicate and enqueues job when admin" do
    admin = users(:admin)
    ApplicationController.any_instance.stubs(:current_user).returns(admin)

    @voice_recording.media.attach(
      io: StringIO.new("fake audio"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )
    @voice_recording.update!(diarization_data: {"fotheidil_video_id" => "123"})

    assert_difference("VoiceRecording.count") do
      assert_enqueued_with(job: ProcessFotheidilVideoJob) do
        post retranscribe_voice_recording_url(@voice_recording)
      end
    end

    duplicate = VoiceRecording.last
    assert_includes duplicate.description, "Retranscription of"
    assert_includes duplicate.description, @voice_recording.id.to_s
    assert duplicate.media.attached?
    assert_nil duplicate.diarization_status
    assert_nil duplicate.import_status
    assert_equal 0, duplicate.dictionary_entries_count
    assert_redirected_to voice_recording_url(duplicate)
  end

  test "retranscribe denied for non-admin user" do
    non_admin = users(:two)
    ApplicationController.any_instance.stubs(:current_user).returns(non_admin)

    assert_no_difference("VoiceRecording.count") do
      post retranscribe_voice_recording_url(@voice_recording)
    end

    assert_response :redirect
  end

  test "should get index with list view" do
    get voice_recordings_url(view: "list")
    assert_response :success
    assert_select 'div[class*="w-full"]', minimum: 1
  end

  test "should get index with map view" do
    get voice_recordings_url(view: "map")
    assert_response :success
  end

  test "should get index with tag filter" do
    @voice_recording.tag_list.add("test_tag")
    @voice_recording.save

    get voice_recordings_url(tag: "test_tag")
    assert_response :success
  end

  test "should get tags index" do
    @voice_recording.tag_list.add("test_tag")
    @voice_recording.save

    get tags_voice_recordings_url
    assert_response :success
    assert_select 'h1', text: "All Tags"
  end

  test "tags index preserves query params in pagination" do
    @voice_recording.tag_list.add("test_tag")
    @voice_recording.save

    get tags_voice_recordings_url(page: 1)
    assert_response :success
  end

  test "tags index supports search" do
    @voice_recording.tag_list.add("searchable_tag")
    @voice_recording.save

    get tags_voice_recordings_url(search: "searchable")
    assert_response :success
  end

  test "tags index supports sorting by name" do
    @voice_recording.tag_list.add("zebra_tag", "apple_tag")
    @voice_recording.save

    get tags_voice_recordings_url(order: "name")
    assert_response :success
  end
end
