require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Abairt
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0


    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.action_mailer.default_url_options = { host: "localhost:3000" }

    # override migrations path
    config.paths['db/migrate'] = ['migrations']

    # support fts
    config.active_record.schema_format = :sql

    # assets issue
    config.assets.css_compressor = :yui

    # new cache format
    config.active_support.cache_format_version = 7.0

    # to_s
    config.active_support.disable_to_s_conversion = true

    config.to_prepare do
      ActionText::ContentHelper.allowed_tags << "iframe"
    end
  end
end
