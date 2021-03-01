# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = 'https://f80c229494bd45f4bd1522bebbe318c3@o353348.ingest.sentry.io/5656899'
  config.breadcrumbs_logger = [:active_support_logger]

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.traces_sample_rate = 0.5
  # or
  config.traces_sampler = lambda do |_context|
    true
  end
end
