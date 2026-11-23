# frozen_string_literal: true

module Transcription
  # "Accept all" on a transcription run (#133): uses the new text on every
  # pending differing line whose entry is unconfirmed, one at a time through
  # AcceptCandidate. Confirmed entries and new segments are left for a person.
  #
  #   Transcription::AcceptAll.call(run, by: user)  # => number accepted
  class AcceptAll
    def self.call(run, by:)
      run.transcription_candidates.acceptable_in_bulk.includes(:dictionary_entry).in_time_order
        .count { |candidate| AcceptCandidate.call(candidate, by:) }
    end
  end
end
