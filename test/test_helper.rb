ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "httparty"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  private

  def with_html_page(filename: 'test_output.html')
    path = Rails.root.join('tmp', filename)
    File.write(path, response.body)

    case RbConfig::CONFIG['host_os']
    when /darwin/
      system('open', path.to_s)  # Convert Pathname to String
    when /linux/
      system('xdg-open', path.to_s)
    when /mswin|mingw/
      system('start', path.to_s)
    end

    yield if block_given?
  ensure
    # File.delete(path) if File.exist?(path)
  end
end
