# frozen_string_literal: true

require "test_helper"

class WellKnownControllerTest < ActionDispatch::IntegrationTest
  test "assetlinks.json lets the Android app open the site's links" do
    get "/.well-known/assetlinks.json"

    assert_response :success
    target = JSON.parse(response.body).first["target"]
    assert_equal "com.abairt.listen", target["package_name"]
    assert_match(/\A([0-9A-F]{2}:){31}[0-9A-F]{2}\z/, target["sha256_cert_fingerprints"].first)
  end
end
