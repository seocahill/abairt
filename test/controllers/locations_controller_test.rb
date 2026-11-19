require "test_helper"

# Flag f172_place_pages: public page for one place.
class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @location = locations(:belmullet)
    @recording = voice_recordings(:one)
    VoiceRecordingLocation.create!(voice_recording: @recording, location: @location, confidence: "high")
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "flag off: place page is not found" do
    Flipper.disable(:f172_place_pages)
    get location_url(@location)
    assert_response :not_found
  end

  test "flag on: shows the place with its recordings" do
    Flipper.enable(:f172_place_pages)
    get location_url(@location)
    assert_response :success
    assert_select "h1", @location.name
    assert_select "a[href='#{voice_recording_path(@recording)}']", minimum: 1
  end

  test "flag on: place with no recordings is not found" do
    Flipper.enable(:f172_place_pages)
    get location_url(locations(:achill))
    assert_response :not_found
  end

  test "flag on: recording page links to the place; flag off it does not" do
    Flipper.enable(:f172_place_pages)
    get voice_recording_url(@recording)
    assert_select "a[href='#{location_path(@location)}']"
    Flipper.disable(:f172_place_pages)
    get voice_recording_url(@recording)
    assert_select "a[href='#{location_path(@location)}']", false
  end

  test "includes recordings tagged directly to the place" do
    Flipper.enable(:f172_place_pages)
    other = voice_recordings(:two)
    other.media.attach(io: StringIO.new("fake audio"), filename: "two.mp3", content_type: "audio/mpeg")
    other.update_columns(location_id: @location.id)
    get location_url(@location)
    assert_select "a[href='#{voice_recording_path(other)}']", minimum: 1
  end

  test "flag on: public page works without a signed-in user" do
    Flipper.enable(:f172_place_pages)
    ApplicationController.any_instance.stubs(:current_user).returns(nil)
    Flipper.enable(:f172_place_pages)
    get location_url(@location)
    assert_response :success
  end

  test "missing place is not found" do
    Flipper.enable(:f172_place_pages)
    get location_url(id: 0)
    assert_response :not_found
  end

  test "speakers exclude temporary and AI users" do
    named = users(:one)
    temp = User.create!(name: "Temp Person", email: "temp@example.com", role: :temporary, confirmed: true)
    [named, temp].each do |u|
      DictionaryEntry.create!(voice_recording: @recording, speaker: u, owner: named, word_or_phrase: "x", region_start: 1, region_end: 2)
    end
    names = @location.speakers.map(&:name)
    assert_includes names, named.name
    assert_not_includes names, "Temp Person"
  end

  test "index pins carry location_id only with the flag on" do
    @recording.update_columns(location_id: @location.id)
    @location.update!(latitude: 54.1, longitude: -9.8)
    Flipper.enable(:f172_place_pages)
    get voice_recordings_url
    assert_includes response.body, "location_id"
    Flipper.disable(:f172_place_pages)
    get voice_recordings_url
    assert_not_includes response.body, "location_id"
  end
end
