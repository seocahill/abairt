# frozen_string_literal: true

# Re-transcribing a recording (#133) is behind f133_retranscribe: with the
# flag off its pages and actions aren't there at all.
module RetranscribeFlag
  extend ActiveSupport::Concern

  included do
    before_action :ensure_retranscribe_enabled
  end

  private

  def ensure_retranscribe_enabled
    raise ActionController::RoutingError, "Not Found" unless Flipper.enabled?(:f133_retranscribe, current_user)
  end
end
