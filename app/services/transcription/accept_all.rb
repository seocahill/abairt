# frozen_string_literal: true

module Transcription
  # The bulk buttons on a transcription run (#133), one candidate at a time
  # through AcceptCandidate:
  #
  # - `kind: :differs` ("Accept all") uses the new text on every pending
  #   differing line whose entry is unconfirmed. Confirmed entries and new
  #   segments are left for a person. With `hide_cosmetic`, lines that differ
  #   only in case or punctuation are left too, as the page doesn't show them.
  # - `kind: :timing` gives every pending line without times the times found
  #   for it. Its text is never touched.
  #
  # `seen_at` is when the person loaded the page. An entry whose text was
  # changed since then is skipped, so a correction made meanwhile is never
  # overwritten unseen.
  #
  #   Transcription::AcceptAll.call(run, by: user, seen_at: 5.minutes.ago)
  #   # => {accepted: 3, skipped: 1}
  class AcceptAll
    def self.call(run, by:, seen_at:, kind: :differs, hide_cosmetic: false)
      new(run, by:, seen_at:, kind:, hide_cosmetic:).call
    end

    def initialize(run, by:, seen_at:, kind:, hide_cosmetic:)
      @run = run
      @user = by
      @seen_at = seen_at
      @kind = kind
      @hide_cosmetic = hide_cosmetic
    end

    def call
      unchanged, changed = candidates.partition { |candidate| unchanged_since_seen?(candidate) }
      {accepted: unchanged.count { |candidate| AcceptCandidate.call(candidate, by: @user) }, skipped: changed.size}
    end

    private

    def candidates
      scope = (@kind == :timing) ? @run.transcription_candidates.timing_in_bulk : @run.transcription_candidates.acceptable_in_bulk
      candidates = scope.includes(:dictionary_entry).in_time_order.to_a
      @hide_cosmetic ? candidates.reject(&:cosmetic?) : candidates
    end

    # Only the text matters: timing never overwrites anything.
    def unchanged_since_seen?(candidate)
      @kind == :timing || candidate.dictionary_entry.updated_at <= @seen_at
    end
  end
end
