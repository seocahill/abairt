class ReifiesPolicy < ApplicationPolicy
  def create?
    user == record.owner
  end
end
