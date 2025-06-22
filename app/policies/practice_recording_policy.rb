# frozen_string_literal: true

class PracticeRecordingPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end 