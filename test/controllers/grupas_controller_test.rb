require "test_helper"

class GrupasControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get grupas_index_url
    assert_response :success
  end

  test "should get show" do
    get grupas_show_url
    assert_response :success
  end
end
