class ReifiesPolicy < ApplicationPolicy
  def create?
    return unless user
    
    user == record.owner || user.admin? || user.teacher? || user.api_user?
  end
end
