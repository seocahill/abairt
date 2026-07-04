# frozen_string_literal: true

require "test_helper"

# Covers the OAuth discovery documents and Dynamic Client Registration endpoint that MCP
# clients (Claude web) use before starting the authorization code flow.
class McpOauthDiscoveryTest < ActionDispatch::IntegrationTest
  test "protected resource metadata advertises this server as the resource" do
    get "/.well-known/oauth-protected-resource"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "#{base_url}/mcp", json["resource"]
    assert_includes json["authorization_servers"], base_url
    assert_includes json["scopes_supported"], "mcp"
    assert_equal ["header"], json["bearer_methods_supported"]
  end

  test "protected resource metadata is reachable with the resource path suffix" do
    get "/.well-known/oauth-protected-resource/mcp"
    assert_response :success
    assert_equal "#{base_url}/mcp", JSON.parse(response.body)["resource"]
  end

  test "authorization server metadata points at the doorkeeper endpoints" do
    get "/.well-known/oauth-authorization-server"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal base_url, json["issuer"]
    assert_equal "#{base_url}/oauth/authorize", json["authorization_endpoint"]
    assert_equal "#{base_url}/oauth/token", json["token_endpoint"]
    assert_equal "#{base_url}/oauth/register", json["registration_endpoint"]
    assert_includes json["code_challenge_methods_supported"], "S256"
    assert_includes json["grant_types_supported"], "authorization_code"
  end

  test "registers a public client via dynamic client registration" do
    assert_difference -> { Doorkeeper::Application.count }, 1 do
      post "/oauth/register",
        params: {
          client_name: "Claude",
          redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
          token_endpoint_auth_method: "none"
        }.to_json,
        headers: {"Content-Type" => "application/json"}
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert json["client_id"].present?
    assert_equal "none", json["token_endpoint_auth_method"]
    refute json.key?("client_secret"), "public clients must not receive a secret"

    application = Doorkeeper::Application.find_by(uid: json["client_id"])
    assert_not_nil application
    refute application.confidential?
    assert_includes application.redirect_uri, "https://claude.ai/api/mcp/auth_callback"
  end

  test "registers a confidential client with a secret" do
    post "/oauth/register",
      params: {redirect_uris: ["https://example.com/callback"]}.to_json,
      headers: {"Content-Type" => "application/json"}

    assert_response :created
    json = JSON.parse(response.body)
    assert json["client_secret"].present?
    assert Doorkeeper::Application.find_by(uid: json["client_id"]).confidential?
  end

  test "rejects registration without a redirect uri" do
    assert_no_difference -> { Doorkeeper::Application.count } do
      post "/oauth/register",
        params: {client_name: "Bad"}.to_json,
        headers: {"Content-Type" => "application/json"}
    end

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", JSON.parse(response.body)["error"]
  end

  private

  def base_url
    "http://www.example.com"
  end
end
