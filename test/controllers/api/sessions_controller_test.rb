# frozen_string_literal: true

require "test_helper"

module Api
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    setup { @user = users(:john) }

    def link_token(user = @user) = user.generate_token_for(:app_login)

    test "swaps the link's token for the account's API token" do
      post api_sessions_path, params: {token: link_token}

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal @user.reload.api_token, body["api_token"]
      assert_equal @user.name, body["name"]
    end

    test "the API token works on the recordings API" do
      post api_sessions_path, params: {token: link_token}
      token = JSON.parse(response.body)["api_token"]

      get api_voice_recordings_path, headers: {"Authorization" => "Bearer #{token}"}

      assert_response :success
    end

    test "a link works once" do
      token = link_token
      post api_sessions_path, params: {token: token}
      assert_response :success

      post api_sessions_path, params: {token: token}

      assert_response :unauthorized
    end

    test "a link runs out after fifteen minutes" do
      token = link_token

      travel 16.minutes do
        post api_sessions_path, params: {token: token}
      end

      assert_response :unauthorized
    end

    test "a new request for a link replaces the one before" do
      old = link_token
      @user.regenerate_login_token

      post api_sessions_path, params: {token: old}

      assert_response :unauthorized
    end

    test "gives nothing for a made-up token" do
      post api_sessions_path, params: {token: "nonsense"}

      assert_response :unauthorized
    end

    test "gives nothing to an account that is not approved" do
      post api_sessions_path, params: {token: link_token(users(:five))}

      assert_response :unauthorized
    end

    test "makes an API token for an account that has none" do
      @user.update_columns(api_token: nil)

      post api_sessions_path, params: {token: link_token}

      assert_response :success
      assert_predicate JSON.parse(response.body)["api_token"], :present?
    end
  end
end
