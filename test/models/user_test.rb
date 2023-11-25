require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "quality method returns correct quality based on ability" do
    user = users(:one)

    assert_equal user.ability, "A1"
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
end
