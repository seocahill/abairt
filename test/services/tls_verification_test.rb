require "test_helper"

class TlsVerificationTest < ActiveSupport::TestCase
  test "outbound abair.ie calls never disable TLS verification" do
    sources = %w[synthesize_text_to_speech_service service_monitoring_service].map { |f| Rails.root.join("app/services/#{f}.rb").read }

    sources.each { |source| assert_no_match(/VERIFY_NONE/, source) }
  end
end
