require "test_helper"

class UserFlipperTest < ActiveSupport::TestCase
  test "flag can be enabled for admins only" do
    Flipper.enable_group :f72_example, :admins

    assert Flipper.enabled?(:f72_example, users(:admin))
    refute Flipper.enabled?(:f72_example, users(:two))
  end

  test "flag can be enabled for a named user" do
    Flipper.enable_actor :f72_example, users(:two)

    assert Flipper.enabled?(:f72_example, users(:two))
    refute Flipper.enabled?(:f72_example, users(:admin))
  end

  test "flags are off by default" do
    refute Flipper.enabled?(:f72_example, users(:admin))
  end

  test "admins group ignores unconfirmed admins and non-users" do
    Flipper.enable_group :f72_example, :admins
    unconfirmed = users(:admin).tap { |u| u.confirmed = false }

    refute Flipper.enabled?(:f72_example, unconfirmed)
    refute Flipper.enabled?(:f72_example, nil)
  end
end
