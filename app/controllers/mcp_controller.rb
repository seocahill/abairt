# frozen_string_literal: true

# Model Context Protocol (MCP) endpoint exposed over the Streamable HTTP transport so that
# Claude web (and other MCP clients) can call the abairt tools.
#
# Requests are authorized with a Doorkeeper OAuth access token. When the token is missing or
# invalid we return a 401 with a `WWW-Authenticate` header pointing at the protected resource
# metadata, which is how MCP clients discover the authorization server (RFC 9728).
class McpController < ActionController::API
  MCP_SCOPE = :mcp

  before_action :authenticate_mcp!

  # Handles POST (JSON-RPC), GET (SSE) and DELETE (session end) per the transport spec.
  def handle
    server = MCP::Server.new(
      name: "abairt",
      title: "Abairt Irish Dictionary",
      version: "1.0.0",
      instructions: "Search and read confirmed Irish-language dictionary entries and " \
                    "transcriptions from the abairt corpus.",
      tools: [
        SearchDictionaryEntriesTool,
        GetDictionaryEntryTool,
        ListRecentTranscriptionsTool
      ],
      server_context: {
        user: current_user,
        host: request.base_url
      }
    )

    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true)

    # Rails may have already consumed the body while parsing params; rewind so the transport
    # can read the raw JSON-RPC payload.
    request.body.rewind if request.body.respond_to?(:rewind)

    status, headers, body = transport.handle_request(request)
    send_transport_response(status, headers, body)
  end

  private

  attr_reader :current_user

  def authenticate_mcp!
    access_token = Doorkeeper::OAuth::Token.authenticate(
      request, *Doorkeeper.config.access_token_methods
    )

    if access_token&.acceptable?([MCP_SCOPE])
      @current_user = User.find_by(id: access_token.resource_owner_id, confirmed: true)
    end

    render_unauthorized unless @current_user
  end

  def render_unauthorized
    metadata_url = "#{request.base_url}/.well-known/oauth-protected-resource"
    response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{metadata_url}")
    render(
      json: {jsonrpc: "2.0", id: nil, error: {code: -32_001, message: "Unauthorized"}},
      status: :unauthorized
    )
  end

  def send_transport_response(status, headers, body)
    payload = +""
    body.each { |part| payload << part.to_s }
    body.close if body.respond_to?(:close)

    headers.each do |name, value|
      next if name.to_s.downcase == "content-length"

      response.headers[name] = value
    end

    render(
      body: payload,
      status: status,
      content_type: headers["Content-Type"] || "application/json"
    )
  end
end
