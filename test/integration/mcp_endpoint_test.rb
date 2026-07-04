# frozen_string_literal: true

require "test_helper"

# Covers the Streamable HTTP MCP endpoint: bearer-token authorization and tool invocation.
class McpEndpointTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @application = Doorkeeper::Application.create!(
      name: "Test MCP Client",
      redirect_uri: "https://claude.ai/api/mcp/auth_callback",
      scopes: "mcp",
      confidential: false
    )
    @token = Doorkeeper::AccessToken.create!(
      application: @application,
      resource_owner_id: @user.id,
      scopes: "mcp",
      expires_in: 2.hours
    )
  end

  test "unauthenticated requests get a 401 pointing at the resource metadata" do
    post "/mcp", params: rpc("tools/list"), headers: json_headers

    assert_response :unauthorized
    assert_match %r{resource_metadata="http://www\.example\.com/\.well-known/oauth-protected-resource"},
      response.headers["WWW-Authenticate"]
  end

  test "an invalid token is rejected" do
    post "/mcp", params: rpc("tools/list"), headers: json_headers("Bearer not-a-real-token")
    assert_response :unauthorized
  end

  test "lists the abairt tools for an authorized client" do
    post "/mcp", params: rpc("tools/list"), headers: json_headers("Bearer #{@token.token}")
    assert_response :success

    tool_names = mcp_result(response).fetch("tools").pluck("name")
    assert_includes tool_names, "search_dictionary_entries"
    assert_includes tool_names, "get_dictionary_entry"
    assert_includes tool_names, "list_recent_transcriptions"
  end

  test "calls the get_dictionary_entry tool" do
    entry = dictionary_entries(:two) # confirmed

    post "/mcp",
      params: rpc("tools/call", name: "get_dictionary_entry", arguments: {id: entry.id}),
      headers: json_headers("Bearer #{@token.token}")
    assert_response :success

    content = mcp_result(response).fetch("content").first.fetch("text")
    payload = JSON.parse(content)
    assert_equal entry.id, payload["id"]
    assert_equal entry.translation, payload["translation"]
  end

  private

  def rpc(method, params = {})
    {jsonrpc: "2.0", id: 1, method: method, params: params}.to_json
  end

  def json_headers(authorization = nil)
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }
    headers["Authorization"] = authorization if authorization
    headers
  end

  # The Streamable HTTP transport may answer either with a plain JSON body or an SSE stream
  # (a `data:` line per event). Pull the JSON-RPC result out of whichever we received.
  def mcp_result(response)
    body = response.body
    json =
      if response.media_type == "text/event-stream"
        data_line = body.each_line.find { |line| line.start_with?("data:") }
        JSON.parse(data_line.sub("data:", "").strip)
      else
        JSON.parse(body)
      end

    json.fetch("result")
  end
end
