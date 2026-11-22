require "test_helper"

# Flag f172_place_pages: one map pin per place instead of one per recording.
class PlacePinsTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @place = locations(:belmullet)
    @place.update!(latitude: 54.225, longitude: -9.99)
  end

  test "one pin per place, newest recordings first" do
    older = record("Older", location: @place, created_at: 2.days.ago)
    newer = record("Newer", location: @place, created_at: 1.day.ago)

    pins = place_pins_for(@place)

    assert_equal 1, pins.size
    pin = pins.first
    assert_equal "Belmullet", pin[:location_name]
    assert_in_delta 54.225, pin[:lat]
    assert_in_delta(-9.99, pin[:lng])
    assert_equal [newer.id, older.id], pin[:recordings].pluck(:id)
    assert_equal 0, pin[:more]
  end

  test "lists a few recordings and counts the rest" do
    7.times { |i| record("Recording #{i}", location: @place) }

    pin = place_pins_for(@place).first

    assert_equal PlacePins::RECORDINGS_PER_PIN, pin[:recordings].size
    assert_equal 2, pin[:more]
  end

  test "a recording with no mapped place falls back to its speaker, without a place name" do
    speaker = User.create!(name: "Pin Speaker", email: "pin-speaker@example.com", role: :speaker, lat_lang: "54.1,-9.7")
    unplaced = record("Unplaced")
    DictionaryEntry.create!(voice_recording: unplaced, speaker: speaker, owner: @owner, word_or_phrase: "x", region_start: 0, region_end: 1)

    pin = PlacePins.new.call.find { |p| p[:recordings].pluck(:id).include?(unplaced.id) }

    assert_nil pin[:location_name]
    assert_nil pin[:location_id]
    assert_in_delta 54.1, pin[:lat]
    assert_in_delta(-9.7, pin[:lng])
    assert_not_includes pin.to_s, "Pin Speaker"
  end

  test "a place without coordinates gets no pin of its own" do
    nowhere = locations(:achill)
    record("Somewhere", location: nowhere)

    assert_empty place_pins_for(nowhere)
  end

  private

  def record(title, **attributes)
    VoiceRecording.create!(title: title, owner: @owner, **attributes)
  end

  def place_pins_for(location)
    PlacePins.new.call.select { |pin| pin[:location_id] == location.id }
  end
end
