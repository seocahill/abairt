require "test_helper"

class AndroidReleaseTest < ActiveSupport::TestCase
  RELEASES = [
    {"tag_name" => "v9.9.9", "published_at" => "2026-11-10T10:00:00Z"},
    {"tag_name" => "android-v0.5.0-rc1", "prerelease" => true, "published_at" => "2026-11-09T10:00:00Z"},
    {"tag_name" => "android-v0.4.1", "published_at" => "2026-11-01T10:00:00Z"},
    {"tag_name" => "android-v0.4.0", "published_at" => "2026-10-01T10:00:00Z"}
  ]

  test "newest takes the first android release and strips the prefix" do
    version = AndroidRelease.newest(RELEASES)

    assert_equal "0.4.1", version.number
    assert_equal Date.new(2026, 11, 1), version.published_on
  end

  test "newest is nil when there is no android release" do
    assert_nil AndroidRelease.newest([{"tag_name" => "v1.0"}])
    assert_nil AndroidRelease.newest([])
  end

  test "refresh caches the version and latest reads it" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(store)
    assert_nil AndroidRelease.latest
    AndroidRelease.refresh(RELEASES)

    assert_equal "0.4.1", AndroidRelease.latest.number
  end

  test "a failed refresh keeps the previously cached version" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(store)
    AndroidRelease.refresh(RELEASES)
    AndroidRelease.refresh([])

    assert_equal "0.4.1", AndroidRelease.latest.number
  end

  test "fetch_releases returns an empty list when GitHub cannot be reached" do
    Net::HTTP.stubs(:start).raises(Timeout::Error)

    assert_equal [], AndroidRelease.fetch_releases
  end

  test "fetch_releases returns an empty list on an error response" do
    Net::HTTP.stubs(:start).returns(Net::HTTPForbidden.new("1.1", "403", "Forbidden"))

    assert_equal [], AndroidRelease.fetch_releases
  end
end
