require "test_helper"

# Without these two endpoints the browser never offers "Add to Home Screen",
# which is the only thing that makes the learner side a one-tap affair.
class PwaTest < ActionDispatch::IntegrationTest
  test "serves a manifest that opens straight onto the record screen" do
    get pwa_manifest_url

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "standalone", manifest["display"]
    assert_equal new_question_path, manifest["start_url"]
    assert manifest["icons"].any? { |icon| icon["sizes"] == "512x512" }
  end

  test "serves a service worker" do
    get pwa_service_worker_url

    assert_response :success
    # A worker the browser will actually accept has to claim the lifecycle.
    assert_match "install", response.body
    assert_match "activate", response.body
  end
end
