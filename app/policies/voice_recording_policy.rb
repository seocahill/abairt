class VoiceRecordingPolicy < ApplicationPolicy
  def preview?
    true
  end

  def create?
    return unless user

    # Only teachers, api_users, and admins can create new recordings
    # Students can edit existing transcriptions but not create new recordings
    user&.teacher? || user&.api_user? || user&.admin?
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
    user&.admin? || user&.teacher? || user&.api_user?
  end

  def destroy?
    return unless user
    # only owners can destroy dictionary entries
    true if user == record.owner
  end

  def retranscribe?
    user&.admin?
  end

  def autocorrect?
    user&.admin?
  end

  def import_status?
    # Same permission as show - anyone can check import status
    true
  end
end
