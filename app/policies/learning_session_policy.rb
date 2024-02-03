class LearningSessionPolicy < ApplicationPolicy
  def index?
    true if user
  end

  def show?
    true if user == record.user
  end

  def create?
    true if user
  end
end
