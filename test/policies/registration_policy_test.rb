require 'test_helper'

class RegistrationPolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @policy = RegistrationPolicy.new(@user, User.new)
  end

  def test_new
    assert @policy.new?
  end

  def test_create
    assert @policy.create?
  end
end
