# frozen_string_literal: true

require "test_helper"

# The 1926 Gaeltacht map is a static page served from public/1926.
class Gaeltacht1926PageTest < ActionDispatch::IntegrationTest
  test "the map page is served at /1926" do
    get "/1926"
    assert_response :success
    assert_includes response.body, "<title>An Ghaeltacht, 1926</title>"
    assert_includes response.body, "/1926/overlay.png"
  end

  test "the map overlay image is served" do
    get "/1926/overlay.png"
    assert_response :success
    assert_equal "image/png", response.media_type
  end
end
