require "test_helper"

# CI installs Ruby from .ruby-version; production is built from the
# Dockerfile's RUBY_VERSION. Keep them the same so production runs what CI
# tests (#209).
class RubyVersionPinsTest < ActiveSupport::TestCase
  test "the Dockerfiles build on the Ruby version in .ruby-version" do
    %w[Dockerfile Dockerfile.test].each do |dockerfile|
      assert_equal ruby_version_file, dockerfile_ruby(dockerfile),
        "#{dockerfile} ARG RUBY_VERSION must match .ruby-version"
    end
  end

  test "Gemfile.lock records the Ruby version in .ruby-version" do
    locked = Rails.root.join("Gemfile.lock").read[/^RUBY VERSION\s+ruby (\d+\.\d+\.\d+)/, 1]
    assert_equal ruby_version_file, locked, "Run `bundle lock` on Ruby #{ruby_version_file}"
  end

  private

  def ruby_version_file
    Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-")
  end

  def dockerfile_ruby(name)
    Rails.root.join(name).read[/^ARG RUBY_VERSION=(\S+)/, 1]
  end
end
