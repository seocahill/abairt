# frozen_string_literal: true

module Admin
  class ApiTokenPolicy < ApplicationPolicy
    def index?
      user&.admin?
    end

    def create?
      user&.admin?
    end

    def update?
      user&.admin?
    end

    def destroy?
      user&.admin?
    end
  end
end

