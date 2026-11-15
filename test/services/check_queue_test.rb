require "test_helper"

class CheckQueueTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:one)
    @recording.dictionary_entries.destroy_all
    @first, @second, @third = [1, 2, 3].map do |n|
      DictionaryEntry.create!(voice_recording: @recording, speaker: users(:one), owner: users(:one),
        word_or_phrase: "line #{n}", region_start: n, region_end: n + 1)
    end
    @queue = CheckQueue.new(@recording)
  end

  test "starts at the first unchecked line" do
    assert_equal @first, @queue.current
    @first.update!(accuracy_status: :confirmed)
    assert_equal @second, CheckQueue.new(@recording).current
  end

  test "asks for a given line, unless it is already checked" do
    assert_equal @third, @queue.current(@third.id)
    @third.update!(accuracy_status: :confirmed)
    assert_equal @first, @queue.current(@third.id)
  end

  test "moves forward and back, wrapping round" do
    assert_equal @second, @queue.following(@first)
    assert_equal @first, @queue.following(@third)
    assert_equal @first, @queue.preceding(@second)
    assert_equal @third, @queue.preceding(@first)
  end

  test "has nowhere to go when it is the only line left" do
    @second.update!(accuracy_status: :confirmed)
    @third.update!(accuracy_status: :confirmed)
    assert_nil CheckQueue.new(@recording).following(@first)
  end

  test "counts what is left and the whole" do
    @first.update!(accuracy_status: :confirmed)
    queue = CheckQueue.new(@recording)
    assert_equal 2, queue.remaining
    assert_equal 3, queue.total
  end
end
