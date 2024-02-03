# app/policies/course_policy.rb
class CoursePolicy < ApplicationPolicy
  def index?
    user.admin? || user.teacher?
  end

  def show?
    user.admin? || user.teacher?
  end

  def create?
    user.admin? || user.teacher?
  end

  def new?
    create?
  end

  def update?
    user.admin? || (user.teacher? && record.user == user)
  end

  def edit?
    update?
  end

  def destroy?
    user.admin? || (user.teacher? && record.user == user)
  end
end
