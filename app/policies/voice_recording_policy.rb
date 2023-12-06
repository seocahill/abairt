class VoiceRecordingPolicy < ApplicationPolicy
  def preview?
    true
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
