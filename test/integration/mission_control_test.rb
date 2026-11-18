require "test_helper"

class MissionControlTest < ActionDispatch::IntegrationTest
  test "Mission Control's own basic auth is off because AdminConstraint guards /jobs" do
    assert_equal false, MissionControl::Jobs.http_basic_auth_enabled
  end

  test "a non-admin cannot reach the jobs dashboard" do
    sign_in_as(users(:two))
    get "/jobs"
    assert_response :not_found
  end

  private

  def sign_in_as(user)
    user.regenerate_login_token if user.login_token.blank?
    post login_path, params: {token: user.login_token}
  end
end
