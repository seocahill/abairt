require "test_helper"

class SentryInitializerTest < ActiveSupport::TestCase
  INITIALIZER = Rails.root.join("config/initializers/sentry.rb")

  teardown { reload_initializer }

  test "reports and forwards logs from production servers" do
    reload_initializer(dummy: nil)
    Sentry.configuration.environment = "production"

    assert Sentry.configuration.sending_allowed?
    assert Sentry.configuration.enable_logs
    assert_equal [:logger], Sentry.configuration.enabled_patches
  end

  test "never sends during the image build, even in production mode" do
    reload_initializer(dummy: "1")
    Sentry.configuration.environment = "production"

    refute Sentry.configuration.sending_allowed?
    refute Sentry.configuration.enable_logs
    assert_empty Sentry.configuration.enabled_patches
  end

  private

  def reload_initializer(dummy: ENV["SECRET_KEY_BASE_DUMMY"])
    previous = ENV["SECRET_KEY_BASE_DUMMY"]
    ENV["SECRET_KEY_BASE_DUMMY"] = dummy
    Sentry.close
    load INITIALIZER
  ensure
    ENV["SECRET_KEY_BASE_DUMMY"] = previous
  end
end
