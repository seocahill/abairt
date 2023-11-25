require 'test_helper'

class UserPolicyTest < ActiveSupport::TestCase
  def setup
    users(:two).update_columns(role: User.roles[:admin])
  end

  def test_new
    current_user = users(:one)
    policy = UserPolicy.new(current_user, nil)

    refute policy.new?

    current_user = users(:two)
    policy = UserPolicy.new(current_user, nil)

    assert policy.new?
  end

  def test_create
    current_user = users(:one)
    policy = UserPolicy.new(current_user, nil)

    refute policy.create?

    current_user = users(:two)
    policy = UserPolicy.new(current_user, nil)

    assert policy.create?
  end

  def test_update
    # Scenario: true if user == record
    current_user = users(:one)
    policy = UserPolicy.new(current_user, current_user)
    assert policy.update?

    # Scenario: otherwise if user is not a student and record is speaker true
    current_user.role = :teacher # Assuming you have a role attribute
    speaker = users(:four) # Assuming you have a speaker fixture
    policy = UserPolicy.new(current_user, speaker)
    assert policy.update?

    # Scenario: else false
    current_user.role = :student
    policy = UserPolicy.new(current_user, speaker)
    refute policy.update?
  end

  def test_destroy
    # Scenario: true if user == record
    current_user = users(:one)
    policy = UserPolicy.new(current_user, current_user)
    assert policy.destroy?

    # Scenario: false if user != record
    other_user = users(:two)
    policy = UserPolicy.new(current_user, other_user)
    refute policy.destroy?
  end
end
