# app/policies/article_policy.rb
class ArticlePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user&.admin? || user&.teacher?
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
