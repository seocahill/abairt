class RangPolicy < ApplicationPolicy
  def index?
    true if user
  end

  def show?
    true if user
  end
end
