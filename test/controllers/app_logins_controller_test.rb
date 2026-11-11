# frozen_string_literal: true

require "test_helper"

class AppLoginsControllerTest < ActionDispatch::IntegrationTest
  test "says what to do when the link was not opened by the app, without using the token" do
    user = users(:john)
    token = user.generate_token_for(:app_login)

    get app_login_path(token)

    assert_response :success
    assert_equal user, User.find_by_token_for(:app_login, token)
  end
end
