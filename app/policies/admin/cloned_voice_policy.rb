# frozen_string_literal: true

module Admin
  class ClonedVoicePolicy < ApplicationPolicy
    def create?
      user&.admin?
    end

    def destroy?
      user&.admin?
    end
  end
end
