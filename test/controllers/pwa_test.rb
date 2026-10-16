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

  # Chrome refuses to offer "Install app" unless the worker can answer a
  # navigation while offline. Without this the manifest is perfect and nothing
  # installs on Android — and Safari does not care, so it looks fine on an
  # iPhone right up until someone tries it on the other half of the phones.
  test "the service worker can answer a navigation offline" do
    get pwa_service_worker_url

    assert_match(/addEventListener\("fetch"/, response.body)
    assert_match "navigate", response.body
  end
end
