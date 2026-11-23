# frozen_string_literal: true

# Re-transcribing a recording and reviewing what comes back (#133) is for an
# admin or the recording's owner (owner's decision, 2026-11-14).
class TranscriptionRunPolicy < ApplicationPolicy
  def create?
    admin_or_recording_owner?
  end

  def show?
    admin_or_recording_owner?
  end

  def update?
    admin_or_recording_owner?
  end

  private

  def admin_or_recording_owner?
    return false unless user

    user.admin? || user == record.voice_recording.owner
  end
end
