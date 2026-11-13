# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Essential gems
ruby '~> 3.4'
gem 'bcrypt', '~> 3.1.7'
gem 'puma', '~> 7.2', '>= 7.2.1'
gem 'rails', '~> 8.1.0'
gem 'minitest', '~> 5.25'
gem 'redis', '~> 4.0'
gem 'sassc-rails'
gem 'bootsnap', '>= 1.4.4', require: false
gem 'ostruct'

# Other gems
gem 'acts-as-taggable-on'
gem 'aws-sdk-s3', '~> 1.88'
gem 'dotenv', '~> 2.8'
gem 'geocoder', '~> 1.8'
gem 'groupdate', '~> 6.2'
gem 'hotwire-rails', '~> 0.1.3'
gem 'httparty'
gem 'importmap-rails', '~> 2.2.3'
gem 'trailblazer-operation', '~> 0.10.0'
gem 'trailblazer-developer', group: :development
gem 'solid_queue', '~> 1.7'
gem 'mission_control-jobs', '~> 0.1'
gem 'mailjet', '~> 1.7'
gem 'alba', '~> 4.0'
gem 'oj', '~> 3.17', '>= 3.17.3'
gem 'doorkeeper', '~> 5.9' # OAuth 2 provider for MCP authorization
gem 'mcp', '~> 1.10' # Model Context Protocol server for Claude web
gem 'has_scope', '~> 0.9'
gem 'mini_portile2', '~> 2.8.5'
gem 'multi_json', '~> 1.15'
gem 'pagy', '~> 5.2.1'
gem 'paper_trail', '~> 17.0'
gem 'pdf-reader', '~> 2.12'
gem 'sqlite-vec'
gem 'pundit', '~> 2.3'
gem 'rack-cors', '~> 3.0'
gem 'rb_sys', '~> 0.9.87'
gem 'ruby-openai', '~> 6.3.0'
gem 'sentry-rails', '~> 6.7'
gem 'sentry-ruby', '~> 6.7'
gem 'sequel', '~> 5.76'
gem 'sprockets-rails'
gem 'sqlite3', '~> 2.10'
gem 'tailwindcss-rails'
gem 'tiktoken_ruby', '~> 0.0.6'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
# gem 'yui-compressor', '~> 0.12.0'

# Development gems
group :development do
  gem 'dotenv-rails', '~> 2.7'
  gem 'listen', '~> 3.10'
  gem 'web-console', '>= 4.1.0'
end

# Feature flags (see docs/feature_flags.md)
gem "flipper", "~> 1.4"
gem "flipper-active_record", "~> 1.4"
gem "flipper-ui", "~> 1.4"

group :test do
  gem 'mocha'
  gem 'rails-controller-testing'
end

# Development and test gems
group :development, :test do
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'pry-byebug', '~> 3.8'
  gem "standard", ">= 1.35.1"
  gem 'standard-rails'
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
end
