# frozen_string_literal: true

require "test_helper"

# Covers the Streamable HTTP MCP endpoint: bearer-token authorization and tool invocation.
class McpEndpointTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin)
    @application = Doorkeeper::Application.create!(
      name: "Test MCP Client",
      redirect_uri: "https://claude.ai/api/mcp/auth_callback",
      scopes: "mcp",
      confidential: false
    )
    @token = token_for(@admin)
  end

  def token_for(user)
    Doorkeeper::AccessToken.create!(
      application: @application,
      resource_owner_id: user.id,
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

  test "a non-admin token is rejected" do
    non_admin = token_for(users(:one)) # teacher, not admin
    post "/mcp", params: rpc("tools/list"), headers: json_headers("Bearer #{non_admin.token}")
    assert_response :unauthorized
  end

  test "lists the full abairt tool surface for an authorized admin" do
    post "/mcp", params: rpc("tools/list"), headers: json_headers("Bearer #{@token.token}")
    assert_response :success

    tool_names = mcp_result(response).fetch("tools").pluck("name")
    %w[search_dictionary_entries get_dictionary_entry list_recent_transcriptions
      context_search get_voice_recording list_voice_recordings list_speakers get_speaker
      list_tags list_word_lists get_word_list
      save_translation create_dictionary_entry set_entry_accuracy tag_entry
      create_word_list add_to_word_list].each do |name|
      assert_includes tool_names, name
    end
  end

  test "reads expose unconfirmed drafts" do
    draft = dictionary_entries(:one) # unconfirmed

    post "/mcp",
      params: rpc("tools/call", name: "get_dictionary_entry", arguments: {id: draft.id}),
      headers: json_headers("Bearer #{@token.token}")
    assert_response :success

    payload = JSON.parse(mcp_result(response).fetch("content").first.fetch("text"))
    assert_equal draft.id, payload["id"]
    assert_equal "unconfirmed", payload["accuracy_status"]
  end

  test "save_translation edits a draft and records a version" do
    draft = dictionary_entries(:one) # unconfirmed → editable

    assert_difference -> { draft.versions.count }, +1 do
      post "/mcp",
        params: rpc("tools/call", name: "save_translation",
          arguments: {id: draft.id, translation: "A fresh translation"}),
        headers: json_headers("Bearer #{@token.token}")
      assert_response :success
    end

    result = mcp_result(response)
    refute result["isError"], "expected a successful tool result"
    assert_equal "A fresh translation", draft.reload.translation
    assert_equal @admin.id, draft.translator_id
  end

  test "save_translation refuses to edit a confirmed entry" do
    confirmed = dictionary_entries(:two)

    post "/mcp",
      params: rpc("tools/call", name: "save_translation",
        arguments: {id: confirmed.id, translation: "nope"}),
      headers: json_headers("Bearer #{@token.token}")
    assert_response :success

    result = mcp_result(response)
    assert result["isError"], "expected an error result for a locked confirmed entry"
    refute_equal "nope", confirmed.reload.translation
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
