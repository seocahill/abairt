require "test_helper"

# Every JavaScript module is served by the app (#188): a slow or missing CDN
# must not break the player, uploads or maps.
class ImportmapTest < ActionDispatch::IntegrationTest
  # Scripts that only work from their own service, not copies of a library.
  THIRD_PARTY_SERVICES = %w[https://www.google.com/recaptcha/api.js].freeze

  test "every pin is a local asset, not a CDN URL" do
    Rails.application.importmap.packages.each_value do |package|
      assert_no_match %r{\A(https?:)?//}, package.path, "#{package.name} is loaded from a CDN"
      assert Rails.application.assets.find_asset(package.path), "#{package.name}: #{package.path} is not an asset"
    end
  end

  test "app JavaScript loads no script from a URL" do
    loads = Rails.root.glob("app/javascript/**/*.js").flat_map do |file|
      file.read.scan(%r{(?:from|import|\.src\s*=)\s*\(?\s*["'](https?://[^"']+)["']}).flatten.map { "#{file.basename}: #{it}" }
    end

    assert_empty loads
  end

  test "views load no script from a URL" do
    tags = Rails.root.glob("app/views/**/*.erb").flat_map do |file|
      file.read.scan(%r{<script[^>]*\ssrc=["']((?:https?:)?//[^"']+)["']}).flatten
        .excluding(THIRD_PARTY_SERVICES).map { "#{file.basename}: #{it}" }
    end

    assert_empty tags
  end
end
