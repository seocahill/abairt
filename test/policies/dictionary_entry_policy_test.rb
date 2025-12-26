require 'test_helper'

class DictionaryEntryPolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @dictionary_entry = dictionary_entries(:one)
    @dictionary_entry.update(owner: @user)
    @policy = DictionaryEntryPolicy.new(@user, @dictionary_entry)
  end

  test "destroy? allows destruction when user is the owner" do
    assert @policy.destroy?
  end

  test "destroy? does not allow destruction when user is not the owner" do
    other_user = users(:two)
    @dictionary_entry.update(owner: other_user)
    @policy = DictionaryEntryPolicy.new(@user, @dictionary_entry)
    assert_not @policy.destroy?
  end

  test "confirm? allows confirmation for non-student users" do
    assert @policy.confirm?
  end

  test "confirm? does not allow confirmation for student users" do
    student = users(:one)
    student.update(role: :student)
    @policy = DictionaryEntryPolicy.new(student, @dictionary_entry)
    assert_not @policy.confirm?
  end

  test "deconfirm? allows deconfirmation for admin" do
    admin = users(:one)
    admin.update(role: :admin)
    @policy = DictionaryEntryPolicy.new(admin, @dictionary_entry)
    assert @policy.deconfirm?
  end

  test "deconfirm? allows deconfirmation for owner" do
    assert @policy.deconfirm?
  end

  test "update? prevents updates when confirmed" do
    confirmed_entry = dictionary_entries(:two) # confirmed
    @policy = DictionaryEntryPolicy.new(@user, confirmed_entry)
    assert_not @policy.update?
  end

  test "update? allows updates when unconfirmed" do
    assert @policy.update?
  end
end
