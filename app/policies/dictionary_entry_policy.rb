class DictionaryEntryPolicy < ApplicationPolicy
  def show?
    # only owners can destroy dictionary entries
    true if user == record.owner
  end

  def update?
    return false unless user
    # Students can update unconfirmed entries to contribute translations
    # Cannot update confirmed entries unless deconfirming
    return true if record.unconfirmed?
    return true if record.confirmed? && record.accuracy_status_changed?
    false
  end

  def confirm?
    user && !user.student?
  end

  def deconfirm?
    user && (user.admin? || user == record.owner)
  end

  def add_region?
    update?
  end

  def destroy?
    return unless user
    # only owners can destroy dictionary entries
    true if user == record.owner || user.admin?
  end
end
