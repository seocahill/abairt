class VoiceRecordingPolicy < ApplicationPolicy
  def preview?
    true
  end

  def create?
    user.teacher? || user.admin?
  end

  def new?
    create?
  end

  def map?
    true
  end

  def edit?
    # only owners can destroy dictionary entries
    true if user == record.owner
  end

  def destroy?
    # only owners can destroy dictionary entries
    true if user == record.owner
  end
end
