require "test_helper"

# Every JavaScript module is served by the app (#188): a slow or missing CDN
# must not break the player, uploads or maps.
class ImportmapTest < ActionDispatch::IntegrationTest
  test "every pin is a local asset, not a CDN URL" do
    Rails.application.importmap.packages.each_value do |package|
      assert_no_match %r{\A(https?:)?//}, package.path, "#{package.name} is loaded from a CDN"
      assert Rails.application.assets.find_asset(package.path), "#{package.name}: #{package.path} is not an asset"
    end
  end

  test "app JavaScript imports no module from a URL" do
    imports = Rails.root.glob("app/javascript/**/*.js").flat_map do |file|
      file.read.scan(%r{(?:from|import)\s*\(?\s*["'](https?://[^"']+)["']}).flatten.map { "#{file.basename}: #{it}" }
    end

    assert_empty imports
  end
end
