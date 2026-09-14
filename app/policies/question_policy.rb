# frozen_string_literal: true

class QuestionPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def new?
    create?
  end

  class Scope < Scope
    def resolve
      scope.where(asker: user)
    end
  end
end
