# frozen_string_literal: true

# Whoever may review a run may accept or dismiss its candidates.
class TranscriptionCandidatePolicy < ApplicationPolicy
  def update?
    TranscriptionRunPolicy.new(user, record.transcription_run).update?
  end
end
