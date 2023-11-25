require 'test_helper'

class DictionaryEntryPolicyTest < ActiveSupport::TestCase
  def setup
    @user = User.new
    @dictionary_entry = DictionaryEntry.new(owner: @user)
    @policy = DictionaryEntryPolicy.new(@user, @dictionary_entry)
  end

  test "destroy? allows destruction when user is the owner" do
    assert @policy.destroy?
  end

  test "destroy? does not allow destruction when user is not the owner" do
    other_user = User.new
    @dictionary_entry.owner = other_user

    assert_not @policy.destroy?
  end
end
