# frozen_string_literal: true

module Fotheidil
  # Handles authentication with Fotheidil API using token refresh
  # Uses browser service for initial login when refresh token is unavailable or expired
  class AuthenticationService
    attr_reader :access_token, :refresh_token

    def initialize(browser_service = nil)
      @browser_service = browser_service
      @access_token = nil
      @refresh_token = Setting.get("fotheidil.refresh_token") ||
        Rails.application.credentials.dig(:fotheidil, :refresh_token)
      @supabase_anon_key = Rails.application.credentials.dig(:fotheidil, :supabase_anon_key)
      @authenticated = false
    end

    def authenticate
      Rails.logger.info "Authenticating with Fotheidil API"

      if @refresh_token && refresh_access_token
        Rails.logger.info "Successfully refreshed access token"
        @authenticated = true
        return true
      end

      Rails.logger.info "Refresh token failed or unavailable, falling back to browser login"

      if @browser_service && browser_login_and_extract_token
        @authenticated = true
        return true
      end

      Rails.logger.error "Cannot authenticate: no valid refresh token and browser login failed"
      @authenticated = false
      false
    end

    def authenticated?
      @authenticated
    end

    private

    def refresh_access_token
      return false unless @refresh_token && @supabase_anon_key

      Rails.logger.info "Attempting to refresh access token"

      response = HTTParty.post(
        "https://pdntukcptgktuzpynlsv.supabase.co/auth/v1/token?grant_type=refresh_token",
        body: {refresh_token: @refresh_token}.to_json,
        headers: {
          "Content-Type" => "application/json",
          "apikey" => @supabase_anon_key
        }
      )

      return handle_refresh_failure(response) unless response.success?

      process_refresh_response(response)
    rescue => e
      Rails.logger.error "Error refreshing access token: #{e.message}"
      false
    end

    def handle_refresh_failure(response)
      Rails.logger.error "Failed to refresh access token: #{response.code} - #{response.body}"
      false
    end

    def process_refresh_response(response)
      auth_data = JSON.parse(response.body)
      @access_token = auth_data["access_token"]

      update_refresh_token(auth_data["refresh_token"]) if auth_data["refresh_token"]

      Rails.logger.info "Access token refreshed successfully"
      true
    end

    def update_refresh_token(new_token)
      @refresh_token = new_token
      Setting.set("fotheidil.refresh_token", @refresh_token)
      Rails.logger.debug "Updated refresh token in database"
    end

    def browser_login_and_extract_token
      return false unless @browser_service

      Rails.logger.info "Starting browser login to extract tokens"

      return false unless @browser_service.authenticate

      extract_and_store_tokens
    rescue => e
      Rails.logger.error "Browser authentication error: #{e.message}"
      false
    end

    def extract_and_store_tokens
      all_cookies = @browser_service.instance_variable_get(:@driver).manage.all_cookies
      auth_cookie = all_cookies.find { |c| c[:name] == "sb-pdntukcptgktuzpynlsv-auth-token" }

      unless auth_cookie
        Rails.logger.error "No auth cookie found after login"
        return false
      end

      auth_data = decode_auth_cookie(auth_cookie[:value])
      @access_token = auth_data["access_token"]
      @refresh_token = auth_data["refresh_token"]

      Setting.set("fotheidil.refresh_token", @refresh_token)
      Rails.logger.info "Stored new refresh token in database"

      true
    end

    def decode_auth_cookie(cookie_value)
      decoded = URI.decode_www_form_component(cookie_value)
      JSON.parse(decoded)
    end
  end
end
