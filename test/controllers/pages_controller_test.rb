require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get faq" do
    get pages_faq_url
    assert_response :success
  end
end
