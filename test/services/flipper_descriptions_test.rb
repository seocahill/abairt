require "test_helper"

class FlipperDescriptionsTest < ActiveSupport::TestCase
  test "every flag registered with Flipper.add has a description" do
    missing = registered_flags - FlipperDescriptions.new.descriptions.keys
    assert_empty missing, "Add these to config/flipper_descriptions.yml: #{missing.join(", ")}"
  end

  test "flags removed by a later migration are no longer registered" do
    assert_includes registered_flags, "f172_place_pages"
    refute_includes registered_flags, "f75_asr_eval"
    refute_includes registered_flags, "f142_training_progress"
  end

  test "every flag checked in code has a description" do
    checked = Rails.root.glob("app/**/*.{rb,erb}").flat_map { |f| File.read(f).scan(/Flipper\.enabled\?\(:(f\d+_\w+)/).flatten }.uniq
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

  test "escapes HTML in descriptions" do
    file = Tempfile.new(["descriptions", ".yml"])
    file.write({"f1_x" => "<script>x</script>"}.to_yaml)
    file.flush
    html = FlipperDescriptions.new(file.path).for_ui(["f1_x"])["f1_x"]
    assert_includes html, "&lt;script&gt;"
    refute_includes html, "<script>"
  ensure
    file&.close!
  end

  test "an empty file gives no descriptions" do
    file = Tempfile.new(["descriptions", ".yml"])
    assert_empty FlipperDescriptions.new(file.path).for_ui(["f1_x"])
  ensure
    file&.close!
  end

  private

  # Flags added, minus those a later migration removed, reading each
  # migration's `up` (or the whole file when it has none) in order.
  def registered_flags
    Rails.root.glob("db/migrate/*.rb").sort.each_with_object(Set.new) do |file, flags|
      source = File.read(file)
      up = source[/def up\b(.*?)^\s*end\s*\n\s*def down/m, 1] || source
      up.scan(/Flipper\.(add|remove)\(:(\w+)\)/).each { |action, flag| (action == "add") ? flags.add(flag) : flags.delete(flag) }
    end.to_a
  end
end
