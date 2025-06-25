class VoiceRecordingPolicy < ApplicationPolicy
  def preview?
    true
  end

  def create?
    return unless user

    user&.teacher? || user&.admin?
  end

  def new?
    create?
  end

  def edit?
    return unless user
    # only owners can destroy dictionary entries
    user == record.owner
  end

  def speakers?
    user&.admin? || user&.teacher?
  end

  def destroy?
    return unless user
    # only owners can destroy dictionary entries
    true if user == record.owner
  end
end
