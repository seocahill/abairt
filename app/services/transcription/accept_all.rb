# frozen_string_literal: true

module Transcription
  # "Accept all" on a transcription run (#133): uses the new text on every
  # pending differing line whose entry is unconfirmed, one at a time through
  # AcceptCandidate. Confirmed entries and new segments are left for a person.
  #
  # `seen_at` is when the person loaded the page. An entry changed since then
  # is skipped, so a correction made meanwhile is never overwritten unseen.
  #
  #   Transcription::AcceptAll.call(run, by: user, seen_at: 5.minutes.ago)
  #   # => {accepted: 3, skipped: 1}
  class AcceptAll
    def self.call(run, by:, seen_at:)
      candidates = run.transcription_candidates.acceptable_in_bulk.includes(:dictionary_entry).in_time_order.to_a
      unchanged, changed = candidates.partition { |candidate| candidate.dictionary_entry.updated_at <= seen_at }
      {accepted: unchanged.count { |candidate| AcceptCandidate.call(candidate, by:) }, skipped: changed.size}
    end
  end
end
