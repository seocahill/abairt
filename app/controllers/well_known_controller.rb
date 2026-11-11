# frozen_string_literal: true

# Serves the OAuth discovery documents that MCP clients (e.g. Claude web) fetch to learn
# how to authorize against this server.
#
#   * RFC 9728 - OAuth 2.0 Protected Resource Metadata
#   * RFC 8414 - OAuth 2.0 Authorization Server Metadata
#
# Doorkeeper mounts the authorization/token/registration endpoints but does not ship these
# discovery documents, so we build them here from the running Doorkeeper configuration.
class WellKnownController < ActionController::API
  ANDROID_PACKAGE = "com.abairt.listen"
  # SHA-256 of the key the app is released with (see .github/workflows/android-release.yml).
  ANDROID_RELEASE_CERT_SHA256 = "9C:2B:F6:1F:D9:E6:5F:2E:2C:62:43:25:16:DE:93:5C:38:4D:2C:64:1C:5C:D1:93:35:3D:A2:8F:6B:65:5E:E2"

  # GET /.well-known/assetlinks.json
  #
  # Tells Android that the Abairt listening app, signed with the release key,
  # may open links to this site (the app sign-in link in the email).
  def assetlinks
    render json: [{
      relation: %w[delegate_permission/common.handle_all_urls],
      target: {
        namespace: "android_app",
        package_name: ANDROID_PACKAGE,
        sha256_cert_fingerprints: [ANDROID_RELEASE_CERT_SHA256]
      }
    }]
  end

  # GET /.well-known/oauth-protected-resource
  def oauth_protected_resource
    render json: {
      resource: mcp_resource_url,
      authorization_servers: [issuer],
      scopes_supported: supported_scopes,
      bearer_methods_supported: %w[header]
    }
  end

  # GET /.well-known/oauth-authorization-server
  def oauth_authorization_server
    render json: {
      issuer: issuer,
      authorization_endpoint: "#{issuer}/oauth/authorize",
      token_endpoint: "#{issuer}/oauth/token",
      registration_endpoint: "#{issuer}/oauth/register",
      revocation_endpoint: "#{issuer}/oauth/revoke",
      introspection_endpoint: "#{issuer}/oauth/introspect",
      scopes_supported: supported_scopes,
      response_types_supported: %w[code],
      response_modes_supported: %w[query],
      grant_types_supported: %w[authorization_code refresh_token],
      token_endpoint_auth_methods_supported: %w[client_secret_basic client_secret_post none],
      code_challenge_methods_supported: %w[S256]
    }
  end

  private

  def issuer
    request.base_url
  end

  def mcp_resource_url
    "#{issuer}/mcp"
  end

  def supported_scopes
    config = Doorkeeper.config
    (config.default_scopes.all + config.optional_scopes.all).uniq
  end
end
