require "test_helper"

# CI installs Ruby from .ruby-version; production is built from the
# Dockerfile's RUBY_VERSION. Keep them the same so production runs what CI
# tests (#209).
class RubyVersionPinsTest < ActiveSupport::TestCase
  DOCKERFILES = %w[Dockerfile Dockerfile.test].freeze

  test "every RUBY_VERSION in the Dockerfiles matches .ruby-version" do
    pins = DOCKERFILES.index_with { |name| dockerfile(name).scan(/^\s*ARG RUBY_VERSION=["']?([^"'\s]+)/).flatten }

    assert pins.values.all?(&:present?), "Each Dockerfile needs an ARG RUBY_VERSION: #{pins}"
    drifted = pins.transform_values { |versions| versions - [ruby_version_file] }.reject { |_, versions| versions.empty? }
    assert_empty drifted, "ARG RUBY_VERSION must be #{ruby_version_file} (from .ruby-version)"
  end

  test "the Dockerfiles take the Ruby image tag from RUBY_VERSION" do
    hard_coded = DOCKERFILES.index_with { |name| dockerfile(name).scan(%r{^\s*FROM\s+\S*\bruby:(?!\$\{?RUBY_VERSION\b)\S+}) }
      .reject { |_, lines| lines.empty? }
    assert_empty hard_coded, "Use ruby:$RUBY_VERSION-... so the image follows .ruby-version"
  end

  test "Gemfile.lock records the Ruby version in .ruby-version" do
    locked = Rails.root.join("Gemfile.lock").read[/^RUBY VERSION\s+ruby (\d+\.\d+\.\d+)/, 1]
    assert_equal ruby_version_file, locked, "Run `bundle update --ruby` on Ruby #{ruby_version_file}"
  end

  private

  def ruby_version_file
    Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-")
  end

  def dockerfile(name)
    Rails.root.join(name).read
  end
end
