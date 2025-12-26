class UserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.speaker
    end
  end

  def root_redirect?
    true
  end

  def index?
    user&.admin?
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
    # admins can update any user
    return true if user&.admin?
    # if it's your own record, you can edit it
    return true if user == record
    # if it's a speaker, anyone can edit it
    user && record.role == 'speaker'
  end

  def edit?
    update?
  end

  def destroy?
    user == record || user&.admin?
  end

  def approve?
    user&.admin?
  end

  def reject?
    user&.admin?
  end

  def bulk_approve?
    user&.admin?
  end

  def bulk_reject?
    user&.admin?
  end

  def send_email?
    user&.admin?
  end

  def send_to_self?
    user&.admin?
  end

  def generate_api_token?
    (user&.admin? || user&.api_user?) && user == record
  end

  def regenerate_api_token?
    (user&.admin? || user&.api_user?) && user == record
  end

  def revoke_api_token?
    (user&.admin? || user&.api_user?) && user == record
  end
end
