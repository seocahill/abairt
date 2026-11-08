# frozen_string_literal: true

# The Docker image build runs rake tasks (assets:precompile) in production mode
# with SECRET_KEY_BASE_DUMMY set. A build must never depend on reaching Sentry,
# so reporting, log forwarding and the logger patch are all off there.
image_build = ENV["SECRET_KEY_BASE_DUMMY"].present?

Sentry.init do |config|
  config.dsn = "https://b1cdd0ff95a74762b72596ab58013b93@o353348.ingest.sentry.io/5656899"
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # To activate performance monitoring, set one of these options.
  # We recommend adjusting the value in production:
  config.max_breadcrumbs = 5
  config.traces_sample_rate = 0.2
  # or
  config.traces_sampler = lambda do |_context|
    true
  end
  config.enabled_environments = image_build ? [] : %w[production]
  config.excluded_exceptions += ["Pagy::VariableError"]
  config.enable_logs = !image_build
  config.rails.structured_logging.subscribers = {
    action_controller: Sentry::Rails::LogSubscribers::ActionControllerSubscriber,
    active_job: Sentry::Rails::LogSubscribers::ActiveJobSubscriber,
    action_mailer: Sentry::Rails::LogSubscribers::ActionMailerSubscriber
  }
  # Patch Ruby logger to forward logs
  config.enabled_patches = image_build ? [] : [:logger]
end
