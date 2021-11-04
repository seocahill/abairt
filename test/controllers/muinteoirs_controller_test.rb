require "test_helper"

class MuinteoirsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get muinteoirs_show_url
    assert_response :success
  end

  test "should get index" do
    get muinteoirs_index_url
    assert_response :success
  end
end
