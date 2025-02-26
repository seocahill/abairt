require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "quality method returns correct quality based on ability" do
    user = users(:one)

    user.ability = "A1"
    assert_equal "low", user.quality

    user.ability = "A2"
    assert_equal "low", user.quality

    user.ability = "B1"
    assert_equal "low", user.quality

    user.ability = "B2"
    assert_equal "fair", user.quality

    user.ability = "C1"
    assert_equal "good", user.quality

    user.ability = "C2"
    assert_equal "good", user.quality

    user.ability = "native"
    assert_equal "excellent", user.quality
  end

  test "all_entries returns all dictionary and spoken dictionary entries" do
    user = users(:one) # replace with your fixture or factory method
    assert_equal user.all_entries, user.dictionary_entries.or(user.spoken_dictionary_entries)
  end

  test "all_recordings returns all voice and spoken voice recordings" do
    user = users(:one) # replace with your fixture or factory method
    assert_equal user.all_recordings, user.voice_recordings.or(user.spoken_voice_recordings)
  end
end
