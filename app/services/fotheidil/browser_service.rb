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
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless") unless Rails.env.development? || ENV["SELENIUM_HEADFUL"] == "true"
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--window-size=1920,1080")

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

      @driver.navigate.to "https://fotheidil.abair.ie/login"

      wait = Selenium::WebDriver::Wait.new(timeout: 10)
      email_input = wait.until { @driver.find_element(:name, "email") }
      email_input.clear
      email_input.send_keys(@email)

      password_input = @driver.find_element(:name, "password")
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
    end

    private

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
