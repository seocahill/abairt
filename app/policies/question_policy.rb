# frozen_string_literal: true

class QuestionPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def new?
    create?
  end

  # The controllers already scope to current_user.questions, but a question is
  # only ever the asker's to send or delete and the policy should say so.
  def update?
    record.asker == user
  end

  def destroy?
    update?
  end

  class Scope < Scope
    def resolve
      scope.where(asker: user)
    end
  end
end
