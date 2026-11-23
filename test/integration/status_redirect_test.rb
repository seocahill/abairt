require "test_helper"

class StatusRedirectTest < ActionDispatch::IntegrationTest
  test "the old status page sends people to ABAIR's status page" do
    get "/status"
    assert_redirected_to "https://status.abair.ie/status/main"
  end
end
