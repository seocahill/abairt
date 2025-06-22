class ReifiesPolicy < ApplicationPolicy
  def create?
    user == record.owner || user.admin? || user.teacher?
  end
end
