class DictionaryEntryPolicy < ApplicationPolicy
  def show?
    # only owners can destroy dictionary entries
    true if user == record.owner
  end

  def destroy?
    # only owners can destroy dictionary entries
    true if user == record.owner
  end
end
