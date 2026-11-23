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

  test "recording cards play straight from storage, not through the Rails redirect" do
    @voice_recording.media.attach(io: StringIO.new("fake audio"), filename: "test.mp3", content_type: "audio/mpeg")
    @voice_recording.update!(created_at: 1.minute.from_now)

    get voice_recordings_url(view: "list")

    assert_response :success
    urls = css_select("[data-controller='card-player']").pluck("data-card-player-url-value")
    assert_equal 1, urls.size
    # The test service is Disk, so the storage URL is its signed disk URL.
    assert_match %r{\Ahttp://localhost:3000/rails/active_storage/disk/.+/test\.mp3\z}, urls.first
    assert_no_match %r{/blobs/redirect/}, urls.first
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

  test "moment links are inert while the flag is off" do
    add_timed_entries(20)
    Flipper.disable(:f82_moment_links)

    get voice_recording_url(@voice_recording, t: 170)

    assert_response :success
    assert_select "#dictionary_entry_#{@late_entry.id}", false
    assert_select "[data-waveform-start-at-value]", false
    assert_select "#recording-phone-header", false
    assert_select "meta[property='og:title']", false
    assert_select "[data-controller='share-link']", false
  end

  test "moment links open on the page holding the moment when the flag is on" do
    add_timed_entries(20)
    Flipper.enable(:f82_moment_links)

    get voice_recording_url(@voice_recording, t: 170)

    assert_response :success
    assert_select "#dictionary_entry_#{@late_entry.id}"
    assert_select "[data-waveform-start-at-value='170.0']"
    assert_select "[data-waveform-start-entry-id-value='#{@late_entry.id}']"
    assert_select "#recording-phone-header", text: /#{@voice_recording.title}/
    assert_select "meta[property='og:title'][content='#{@voice_recording.title}']"
    assert_select "[data-share-link-url-value*='t=']"
  end

  test "the per-line copy link only appears with the flag on" do
    add_timed_entries(3)
    Flipper.enable(:f82_moment_links)

    get voice_recording_url(@voice_recording)

    assert_select "[data-controller='share-link'][data-share-link-url-value*='t=10.0']"
  end

  test "an unreadable t is ignored when the flag is on" do
    add_timed_entries(3)
    Flipper.enable(:f82_moment_links)

    get voice_recording_url(@voice_recording, t: "soon")

    assert_response :success
    assert_select "[data-waveform-start-at-value]", false
  end

  test "listening controls are inert while the flag is off" do
    add_timed_entries(3)
    Flipper.disable(:f81_listening_controls)

    get voice_recording_url(@voice_recording)

    assert_response :success
    assert_select "[data-waveform-listening-value]", false
    assert_select "[data-controller~='line-seek']", false
    assert_select "[data-waveform-target='loopButton']", false
    assert_select "[data-controller='audio-player']"
  end

  test "listening controls match the player: svg icons, labels, pressed state, 44px hit areas" do
    Flipper.enable(:f81_listening_controls)
    get voice_recording_path(@voice_recording)
    assert_select "[aria-label='Listening controls'] button svg", 4
    assert_select "[aria-label='Loop line'][aria-pressed='false'].min-h-\\[44px\\]"
    assert_select "[data-waveform-target='playButton'].min-h-\\[44px\\]"
  end

  test "play button is unchanged with the flag off" do
    Flipper.disable(:f81_listening_controls)
    get voice_recording_path(@voice_recording)
    assert_select "[data-waveform-target='playButton'].min-h-\\[44px\\]", false
  end

  test "listening controls appear with the flag on" do
    add_timed_entries(3)
    Flipper.enable(:f81_listening_controls)

    get voice_recording_url(@voice_recording)

    assert_response :success
    assert_select "[data-waveform-listening-value='true'][data-waveform-title-value='#{@voice_recording.title}']"
    assert_select "[data-waveform-target='loopButton']"
    assert_select "[data-controller~='line-seek'][data-line-seek-start-value='10.0']"
    assert_select "[data-action='line-seek#play']"
  end

  test "an untimed line keeps its own clip button with the flag on" do
    DictionaryEntry.create!(voice_recording: @voice_recording, speaker: users(:one), owner: users(:one), word_or_phrase: "untimed")
    Flipper.enable(:f81_listening_controls)

    get voice_recording_url(@voice_recording)

    assert_select "[data-controller='audio-player']"
  end

  test "play does not wait for the waveform while the early play flag is off" do
    Flipper.disable(:f125_early_play)

    get voice_recording_url(@voice_recording)

    assert_response :success
    assert_select "[data-controller='waveform']"
    assert_select "[data-waveform-early-play-value]", false
  end

  test "early play is switched on for the waveform with the flag on" do
    Flipper.enable(:f125_early_play)

    get voice_recording_url(@voice_recording)

    assert_response :success
    assert_select "[data-controller='waveform'][data-waveform-early-play-value='true']"
  end

  test "peaks are served as json once generated" do
    @voice_recording.update!(peaks: {"samples_per_second" => 8, "data" => [-0.5, 0.5]})

    get peaks_voice_recording_url(@voice_recording), as: :json

    assert_response :success
    assert_equal [-0.5, 0.5], response.parsed_body["data"]
  end

  test "peaks are not found before they are generated" do
    @voice_recording.update!(peaks: nil)

    get peaks_voice_recording_url(@voice_recording), as: :json

    assert_response :not_found
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

  # Documents the old button (#133): the copy is processed with the original's
  # Fotheidil job, so it re-fetches the old transcript instead of running the
  # model again. Transcription::RerunOperation is the replacement.
  test "retranscribe hands the copy the original's Fotheidil job instead of a new one" do
    ApplicationController.any_instance.stubs(:current_user).returns(users(:admin))
    @voice_recording.media.attach(io: StringIO.new("fake audio"), filename: "test.mp3", content_type: "audio/mpeg")
    @voice_recording.update!(diarization_data: {"fotheidil_video_id" => "123"})

    post retranscribe_voice_recording_url(@voice_recording)

    assert_enqueued_with(job: ProcessFotheidilVideoJob, args: [VoiceRecording.last.id, "123"])
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
    # List view uses multi-column grid
    assert_select 'div[class*="grid-cols-3"]', minimum: 1
  end

  test "list view uses same card partial as map view" do
    get voice_recordings_url(view: "list")
    assert_response :success
    # Same card partial renders audio elements
    assert_select 'audio[preload="none"]', minimum: 0
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

  private

  def add_timed_entries(count)
    speaker = users(:one)
    entries = (0...count).map do |i|
      DictionaryEntry.create!(voice_recording: @voice_recording, speaker: speaker, owner: speaker,
        word_or_phrase: "line #{i}", region_start: i * 10, region_end: i * 10 + 9)
    end
    @late_entry = entries[17]
  end
end
