class RangPolicy < ApplicationPolicy
  def index?
    true if user
  end

  def create?
    true if user&.teacher? || user&.admin?
  end

  def update?
    true if record&.teacher == user
  end

  def destroy?
    true if record&.teacher == user
  end

  def show?
    true if user && (user == record.teacher || record.users.include?(user))
  end
end
