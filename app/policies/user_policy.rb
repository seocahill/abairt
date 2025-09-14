class UserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.speaker
    end
  end

  def root_redirect?
    true
  end

  def create?
    user&.admin?
  end

  def new?
    create?
  end

  def show?
    true
  end

  def update?
    # if it's your own record, you can edit it
    return true if user == record
    # if it's a speaker, anyone can edit it
    user && record.role == 'speaker'
  end

  def edit?
    update?
  end

  def destroy?
    user == record
  end
end
