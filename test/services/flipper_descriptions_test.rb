require "test_helper"

class FlipperDescriptionsTest < ActiveSupport::TestCase
  test "every flag registered with Flipper.add has a description" do
    registered = Dir[Rails.root.join("db/migrate/*.rb")].flat_map { |f| File.read(f).scan(/Flipper\.add\(:(\w+)\)/).flatten }.uniq
    missing = registered - FlipperDescriptions.new.descriptions.keys
    assert_empty missing, "Add these to config/flipper_descriptions.yml: #{missing.join(", ")}"
  end

  test "every flag checked in code has a description" do
    checked = Dir[Rails.root.join("app/**/*.{rb,erb}")].flat_map { |f| File.read(f).scan(/Flipper\.enabled\?\(:(f\d+_\w+)/).flatten }.uniq
    missing = checked - FlipperDescriptions.new.descriptions.keys
    assert_empty missing, "Add these to config/flipper_descriptions.yml: #{missing.join(", ")}"
  end

  test "describes a flag with a link to its issue" do
    html = FlipperDescriptions.new.for_ui(["f81_listening_controls"])["f81_listening_controls"]
    assert_includes html, "https://github.com/seocahill/abairt/issues/81"
  end

  test "ignores unknown flags and escapes text" do
    assert_empty FlipperDescriptions.new.for_ui(["nope"])
    assert_nil FlipperDescriptions.new.issue_url("plain_flag")
  end
end
