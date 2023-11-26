require 'test_helper'

class RangPolicyTest < ActiveSupport::TestCase
  def setup
    @rang = rangs(:one)
  end

  def test_show
    policy = RangPolicy.new(users(:two), @rang)
    refute policy.show?
  end

  def test_index
    policy = RangPolicy.new(nil, nil)
    refute policy.index?
  end

  def test_create
    policy = RangPolicy.new(users(:two), nil)
    refute policy.create?
  end

  def test_update
    policy = RangPolicy.new(users(:two), @rang)
    refute policy.update?
  end

  def test_destroy
    policy = RangPolicy.new(users(:two), @rang)
    refute policy.destroy?
  end
end
