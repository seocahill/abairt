# frozen_string_literal: true

module Oauth
  # OAuth 2.0 Dynamic Client Registration (RFC 7591).
  #
  # Doorkeeper does not ship a registration endpoint, but MCP clients such as Claude web
  # rely on it to self-register before starting the authorization code flow. This endpoint
  # accepts the client metadata document and creates a Doorkeeper::Application from it.
  class RegistrationsController < ActionController::API
    # POST /oauth/register
    def create
      redirect_uris = Array(registration_params[:redirect_uris]).map(&:to_s).compact_blank

      if redirect_uris.empty?
        return render_error("invalid_redirect_uri", "At least one redirect_uri is required")
      end

      application = Doorkeeper::Application.new(
        name: client_name,
        redirect_uri: redirect_uris.join("\n"),
        scopes: requested_scopes,
        confidential: confidential_client?
      )

      if application.save
        render json: registration_response(application, redirect_uris), status: :created
      else
        render_error("invalid_client_metadata", application.errors.full_messages.to_sentence)
      end
    end

    private

    def registration_params
      # RFC 7591 metadata is sent as a JSON body; fall back to standard params.
      params.permit(
        :client_name,
        :token_endpoint_auth_method,
        :scope,
        redirect_uris: [],
        grant_types: [],
        response_types: []
      )
    end

    def client_name
      registration_params[:client_name].presence || "MCP Client"
    end

    def requested_scopes
      scope = registration_params[:scope]
      scope.presence || Doorkeeper.config.default_scopes.to_s
    end

    # Public clients (the common MCP case) authenticate with PKCE and declare
    # `token_endpoint_auth_method: "none"`; everything else gets a client secret.
    def confidential_client?
      registration_params[:token_endpoint_auth_method].to_s != "none"
    end

    def registration_response(application, redirect_uris)
      response = {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        client_name: application.name,
        redirect_uris: redirect_uris,
        grant_types: %w[authorization_code refresh_token],
        response_types: %w[code],
        token_endpoint_auth_method: confidential_client? ? "client_secret_basic" : "none",
        scope: application.scopes.to_s
      }

      if application.confidential?
        response[:client_secret] = application.plaintext_secret
        response[:client_secret_expires_at] = 0 # never expires
      end

      response
    end

    def render_error(error, description)
      render json: {error: error, error_description: description}, status: :bad_request
    end
  end
end
