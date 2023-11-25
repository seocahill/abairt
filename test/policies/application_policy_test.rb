# frozen_string_literal: true

require 'test_helper'

class ApplicationPolicyTest < ActiveSupport::TestCase
  test "index? should always return true" do
    policy = ApplicationPolicy.new(nil, nil)

    assert_equal true, policy.index?
  end

  test "show? should always return true" do
    policy = ApplicationPolicy.new(nil, nil)

    assert_equal true, policy.show?
  end

  test "create? should return true if user exists" do
    user = User.new
    policy = ApplicationPolicy.new(user, nil)

    assert_equal true, policy.create?
  end

  test "new? should delegate to create?" do
    user = User.new
    policy = ApplicationPolicy.new(user, nil)

    assert_equal policy.create?, policy.new?
  end

  test "update? should return true if user exists" do
    user = User.new
    policy = ApplicationPolicy.new(user, nil)

    assert_equal true, policy.update?
  end

  test "edit? should delegate to update?" do
    user = User.new
    policy = ApplicationPolicy.new(user, nil)

    assert_equal policy.update?, policy.edit?
  end

  test "destroy? should return true if user exists" do
    user = User.new
    policy = ApplicationPolicy.new(user, nil)

    assert_equal true, policy.destroy?
  end

  class TestScope < ApplicationPolicy::Scope
    def resolve
      # Define your custom resolve logic for testing here
      []
    end
  end
end