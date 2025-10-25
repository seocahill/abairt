# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Essential gems
ruby '~> 3.4'
gem 'bcrypt', '~> 3.1.7'
gem 'puma', '~> 6.0'
gem 'rails', '~> 7.1.0'
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
gem 'ferrum' # Headless Chrome for browser automation fallback
gem 'selenium-webdriver' # Browser automation for Fotheidil
gem 'importmap-rails', '~> 0.8.2'
gem 'trailblazer-operation', '~> 0.10.0'
gem 'trailblazer-developer', group: :development
gem 'langchainrb', '~> 0.8.2'
gem 'solid_queue', '~> 1.0'
gem 'mission_control-jobs', '~> 0.1'
gem 'madmin', '~> 1.2'
gem 'mailjet', '~> 1.7'
gem 'mini_portile2', '~> 2.8.5'
gem 'multi_json', '~> 1.15'
gem 'pagy', '~> 5.2.1'
gem 'paper_trail', '~> 15.0'
gem 'pdf-reader', '~> 2.12'
# gem 'pg', '~> 1.5'
# gem 'pgvector', '~> 0.2'
gem 'pundit', '~> 2.3'
gem 'rack-cors', '~> 1.1'
gem 'rb_sys', '~> 0.9.87'
gem 'ruby-openai', '~> 6.3.0'
gem 'sentry-rails', '~> 4.2'
gem 'sentry-ruby', '~> 4.2'
gem 'sequel', '~> 5.76'
gem 'sprockets-rails'
gem 'sqlite3', '~> 1.6'
gem 'tailwindcss-rails'
gem 'tiktoken_ruby', '~> 0.0.6'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
# gem 'yui-compressor', '~> 0.12.0'

# Development gems
group :development do
  gem 'dotenv-rails', '~> 2.7'
  gem 'listen', '~> 3.3'
  gem 'web-console', '>= 4.1.0'
end

group :test do
  gem 'capybara', '>= 3.26'
  gem 'mocha'
  gem 'rails-controller-testing'
  gem 'webdrivers'
end

# Development and test gems
group :development, :test do
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'pry-byebug', '~> 3.8'
  gem 'pry-rails', '~> 0.3.9'
  gem "standard", ">= 1.35.1"
  gem 'standard-rails'
end

gem "activerecord-enhancedsqlite3-adapter", "~> 0.8.0"
