# frozen_string_literal: true

class QuestionPolicy < ApplicationPolicy
  # Admins only while this is in beta. The controllers say so too; this is the
  # half that holds if a new entry point forgets to.
  def create?
    user&.admin? == true
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
