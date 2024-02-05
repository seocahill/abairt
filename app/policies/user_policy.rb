class UserPolicy < ApplicationPolicy
  def root_redirect?
    true
  end

  def create?
    user.admin?
  end

  def show?
    return user == record
  end

  def update?
    return true if user&.admin?
    return true if user == record
    true if (user && record.speaker? && !user.student?)
  end

  def destroy?
    user == record
  end
end
