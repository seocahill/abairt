# frozen_string_literal: true

# Shared by the re-transcription review controllers (#133).
#
# Everything is behind f133_retranscribe: with the flag off its pages and
# actions aren't there at all.
module TranscriptionReview
  extend ActiveSupport::Concern

  included do
    before_action :ensure_retranscribe_enabled
  end

  private

  def ensure_retranscribe_enabled
    raise ActionController::RoutingError, "Not Found" unless Flipper.enabled?(:f133_retranscribe, current_user)
  end

  # When the review page was loaded, carried by its forms so "Accept all" can
  # leave alone any line changed since. Missing or garbled counts as the
  # beginning of time, so nothing changed is ever treated as seen.
  def seen_at
    Time.zone.at(Rational(params.require(:seen_at)))
  rescue ArgumentError, ZeroDivisionError, ActionController::ParameterMissing
    Time.zone.at(0)
  end
end
