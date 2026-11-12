require "test_helper"

class FlipperUiTest < ActionDispatch::IntegrationTest
  test "anonymous visitor gets a 404 at /flipper" do
    get "/flipper"
    assert_response :not_found
  end

  test "non-admin gets a 404 at /flipper" do
    user = users(:two)
    user.regenerate_login_token
    post login_path, params: {token: user.login_token}

    get "/flipper"
    assert_response :not_found
  end

  test "admin can open /flipper" do
    admin = users(:admin)
    admin.regenerate_login_token
    post login_path, params: {token: admin.login_token}

    get "/flipper/features"
    assert_response :success
  end

  test "unconfirmed admin gets a 404 at /flipper" do
    admin = users(:admin)
    admin.update_columns(confirmed: false)
    admin.regenerate_login_token
    post login_path, params: {token: admin.login_token}

    get "/flipper"
    assert_response :not_found
  end

  test "non-admin cannot change a flag" do
    user = users(:two)
    user.regenerate_login_token
    post login_path, params: {token: user.login_token}

    post "/flipper/features/f72_example/boolean"
    assert_response :not_found
    refute Flipper.enabled?(:f72_example)
  end
end
