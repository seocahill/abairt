class LearningProgressPolicy < ApplicationPolicy

  def show?
    true if record.learning_session.user == user
  end

  def update?
    true if record.learning_session.user == user
  end
end
