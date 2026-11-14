require "test_helper"

class MomentLinkTest < ActiveSupport::TestCase
  test "parses seconds, clock times and unit times" do
    assert_equal 83.4, MomentLink.parse("83.4")
    assert_equal 83.0, MomentLink.parse("1:23")
    assert_equal 3683.0, MomentLink.parse("1:01:23")
    assert_equal 83.0, MomentLink.parse("1m23s")
    assert_equal 83.0, MomentLink.parse("t=83")
  end

  test "rejects nonsense and negatives" do
    [nil, "", "abc", "-5", "NaN", "1:2:3:4"].each do |value|
      assert_nil MomentLink.parse(value), value.inspect
    end
  end

  test "finds the line being spoken and its page" do
    recording = voice_recordings(:one)
    speaker = users(:one)
    entries = (0...5).map do |i|
      DictionaryEntry.create!(voice_recording: recording, speaker: speaker, owner: speaker,
        word_or_phrase: "line #{i}", region_start: i * 10, region_end: i * 10 + 9)
    end

    moment = MomentLink.new(recording, 25.0)

    assert_equal entries[2], moment.entry
    assert_equal 2, moment.page(2)
    assert_equal 1, MomentLink.new(recording, 0).page(2)
  end

  test "lines without a start time are counted so the page matches the list" do
    recording = voice_recordings(:one)
    speaker = users(:one)
    2.times { |i| DictionaryEntry.create!(voice_recording: recording, speaker: speaker, owner: speaker, word_or_phrase: "untimed #{i}") }
    (0...3).each { |i| DictionaryEntry.create!(voice_recording: recording, speaker: speaker, owner: speaker, word_or_phrase: "l#{i}", region_start: i * 10, region_end: i * 10 + 9) }

    ordered = recording.dictionary_entries.reorder(:region_start).to_a
    target = ordered.find { |e| e.region_start == 10 }

    assert_equal (ordered.index(target) / 2) + 1, MomentLink.new(recording, 10.0).page(2)
  end

  test "falls back to page one when no line matches" do
    assert_equal 1, MomentLink.new(voice_recordings(:one), 50).page(15)
  end
end
