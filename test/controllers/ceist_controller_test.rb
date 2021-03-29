require "test_helper"

class CeistControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get ceist_new_url
    assert_response :success
  end
end
