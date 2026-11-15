# frozen_string_literal: true

# The newest published Android app version, read from GitHub Releases (the
# source of truth: a release is a tag push, not a web deploy).
#
#   AndroidRelease.refresh   # asks GitHub, caches the answer (run by a job)
#   AndroidRelease.latest    # => #<data AndroidRelease::Version number="0.4.1", published_on=...> or nil
#
# `latest` only reads the cache, so a page view never waits on GitHub, and any
# failure just means no version is shown.
class AndroidRelease
  Version = Data.define(:number, :published_on)

  RELEASES_URL = "https://api.github.com/repos/seocahill/abairt/releases"
  TAG_PREFIX = "android-v"
  CACHE_KEY = "android_release/latest"
  CACHE_TTL = 1.day
  REFRESH_LOCK_KEY = "android_release/refresh_requested"
  REFRESH_LOCK_TTL = 5.minutes
  TIMEOUT = 5

  def self.latest
    version = Rails.cache.read(CACHE_KEY)
    request_refresh if version.nil?
    version
  rescue => e
    Rails.logger.warn "AndroidRelease: cache unavailable (#{e.class})"
    nil
  end

  # An empty cache (a new cache store, an eviction) is refilled now rather than at the next hourly
  # run. The lock stops a burst of page views from enqueuing a burst of jobs.
  def self.request_refresh
    return unless Rails.cache.write(REFRESH_LOCK_KEY, true, expires_in: REFRESH_LOCK_TTL, unless_exist: true)

    RefreshAndroidReleaseJob.perform_later
  end

  def self.refresh(releases = fetch_releases)
    version = newest(releases)
    Rails.cache.write(CACHE_KEY, version, expires_in: CACHE_TTL) if version
    version
  end

  def self.newest(releases)
    return unless releases.is_a?(Array)

    release = releases.find { |r| r["tag_name"].to_s.start_with?(TAG_PREFIX) && !r["draft"] && !r["prerelease"] }
    return unless release

    Version.new(
      number: release["tag_name"].delete_prefix(TAG_PREFIX),
      published_on: release["published_at"]&.then { |time| Time.zone.parse(time)&.to_date }
    )
  rescue ArgumentError
    Version.new(number: release["tag_name"].delete_prefix(TAG_PREFIX), published_on: nil)
  end

  def self.fetch_releases
    response = Net::HTTP.start(URI(RELEASES_URL).host, 443, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(URI(RELEASES_URL).request_uri, "Accept" => "application/vnd.github+json", "User-Agent" => "abairt")
    end
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    Rails.logger.warn "AndroidRelease: GitHub answered #{response.code}"
    []
  rescue SocketError, SystemCallError, IOError, Net::ProtocolError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => e
    Rails.logger.warn "AndroidRelease: could not read releases (#{e.class})"
    []
  end
end
