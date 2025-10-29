# frozen_string_literal: true

require "selenium-webdriver"
require "nokogiri"

module Fotheidil
  # Handles browser automation for Fotheidil website interaction
  # Used as fallback when API authentication fails
  class BrowserService
    attr_reader :driver

    def initialize(email = nil, password = nil)
      @email = email || Rails.application.credentials.dig(:fotheidil, :email)
      @password = password || Rails.application.credentials.dig(:fotheidil, :password)
      @driver = nil
    end

    def setup_browser
      # Clean up any zombie browser processes before starting
      cleanup_zombie_processes

      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless") unless Rails.env.development? || ENV["SELENIUM_HEADFUL"] == "true"
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--window-size=1920,1080")

      # Use unique user data directory to prevent conflicts between concurrent sessions
      @user_data_dir = Dir.mktmpdir("chrome_profile_")
      options.add_argument("--user-data-dir=#{@user_data_dir}")

      # Use remote Selenium if SELENIUM_URL is set, otherwise use local Chrome
      if ENV["SELENIUM_URL"].present?
        Rails.logger.info "Connecting to remote Selenium at #{ENV['SELENIUM_URL']}"
        @driver = Selenium::WebDriver.for(
          :remote,
          url: ENV["SELENIUM_URL"],
          options: options
        )
      else
        Rails.logger.info "Using local Chrome browser"
        @driver = Selenium::WebDriver.for :chrome, options: options
      end

      true
    rescue => e
      Rails.logger.error "Browser setup failed: #{e.message}"
      false
    end

    def authenticate
      return false unless setup_browser

      Rails.logger.info "Authenticating with browser automation..."

      # Use the auth-v2 login page which has proper redirects
      # If the main login page is unavailable, this URL will work
      login_url = "https://auth-v2.abair.ie/?ref=https%3A%2F%2Ffotheidil.abair.ie%2Fauth%2Fcallback"
      @driver.navigate.to login_url

      wait = Selenium::WebDriver::Wait.new(timeout: 10)

      # Try to find email input - works for both original and auth-v2 pages
      # auth-v2 uses id="email", original may use name="email"
      email_input = wait.until do
        @driver.find_element(:css, 'input[type="email"], input#email, input[name="email"]')
      end
      email_input.clear
      email_input.send_keys(@email)

      # Try to find password input - works for both pages
      password_input = @driver.find_element(:css, 'input[type="password"], input#password, input[name="password"]')
      password_input.clear
      password_input.send_keys(@password)

      submit_button = @driver.find_element(:css, 'button[type="submit"]')
      submit_button.click

      sleep(3)

      verify_login_success
    rescue => e
      Rails.logger.error "Authentication error: #{e.message}"
      false
    end

    def cleanup
      return unless @driver

      @driver.quit
      Rails.logger.debug "Browser cleaned up"

      # Clean up temporary user data directory
      if @user_data_dir && Dir.exist?(@user_data_dir)
        FileUtils.rm_rf(@user_data_dir)
        Rails.logger.debug "Cleaned up user data directory: #{@user_data_dir}"
      end
    rescue => e
      Rails.logger.warn "Error during cleanup: #{e.message}"
    end

    private

    def cleanup_zombie_processes
      if ENV["SELENIUM_URL"].present?
        # For remote Selenium, try to clean up any orphaned sessions
        cleanup_remote_sessions
      else
        # For local Chrome, kill any zombie Chrome/chromedriver processes
        cleanup_local_chrome_processes
      end
    rescue => e
      Rails.logger.warn "Failed to clean up zombie processes: #{e.message}"
    end

    def cleanup_remote_sessions
      # Connect to remote Selenium and clean up any orphaned sessions
      require "net/http"
      uri = URI(ENV["SELENIUM_URL"])

      # Try to get sessions endpoint
      sessions_uri = URI("#{uri.scheme}://#{uri.host}:#{uri.port}/wd/hub/sessions")
      response = Net::HTTP.get_response(sessions_uri)

      if response.is_a?(Net::HTTPSuccess)
        sessions = JSON.parse(response.body)["value"] rescue []

        sessions.each do |session|
          session_id = session["id"]
          delete_uri = URI("#{uri.scheme}://#{uri.host}:#{uri.port}/wd/hub/session/#{session_id}")
          Net::HTTP.start(delete_uri.host, delete_uri.port) do |http|
            http.delete(delete_uri.path)
          end
          Rails.logger.info "Cleaned up remote Selenium session: #{session_id}"
        rescue => e
          Rails.logger.warn "Failed to delete session #{session_id}: #{e.message}"
        end
      end
    rescue => e
      Rails.logger.debug "Could not clean up remote sessions: #{e.message}"
    end

    def cleanup_local_chrome_processes
      # Kill zombie Chrome and chromedriver processes
      chrome_processes = `ps aux | grep -E 'chrome|chromedriver' | grep -v grep | awk '{print $2}'`.split("\n")

      chrome_processes.each do |pid|
        begin
          Process.kill("TERM", pid.to_i)
          Rails.logger.info "Killed zombie browser process: #{pid}"
        rescue Errno::ESRCH
          # Process already dead
        rescue Errno::EPERM
          Rails.logger.warn "No permission to kill process #{pid}"
        end
      end
    rescue => e
      Rails.logger.debug "Could not clean up local Chrome processes: #{e.message}"
    end

    def verify_login_success
      current_url = @driver.current_url
      page_source = @driver.page_source

      Rails.logger.info "Current URL: #{current_url}"

      if page_source.include?("You are not signed in") || current_url.include?("/login")
        Rails.logger.error "Login failed - still on login page"
        false
      elsif page_source.include?("Upload") || current_url.include?("/upload") || current_url == "https://fotheidil.abair.ie/"
        Rails.logger.info "Login successful!"
        true
      else
        Rails.logger.warn "Unclear login status - Page title: #{@driver.title}"
        nil
      end
    end
  end
end
