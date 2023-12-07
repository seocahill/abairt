class RegistrationPolicy < ApplicationPolicy
  def new?
    true
  end

  def create?
    !record.confirmed
  end
end
