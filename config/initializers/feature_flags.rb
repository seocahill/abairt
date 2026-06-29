# frozen_string_literal: true

# Application-level feature flags.
#
# Set ENV vars to enable. Defaults to disabled so new features can ship
# dark until they're ready to roll out.
Rails.application.config.x.features = ActiveSupport::OrderedOptions.new
Rails.application.config.x.features.radio = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("RADIO_ENABLED", "false")
)
