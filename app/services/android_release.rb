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
  TIMEOUT = 5

  def self.latest
    Rails.cache.read(CACHE_KEY)
  end

  def self.refresh(releases = fetch_releases)
    version = newest(releases)
    Rails.cache.write(CACHE_KEY, version, expires_in: CACHE_TTL) if version
    version
  end

  def self.newest(releases)
    release = releases.find { |r| r["tag_name"].to_s.start_with?(TAG_PREFIX) && !r["draft"] && !r["prerelease"] }
    return unless release

    Version.new(
      number: release["tag_name"].delete_prefix(TAG_PREFIX),
      published_on: release["published_at"]&.then { |time| Time.zone.parse(time)&.to_date }
    )
  end

  def self.fetch_releases
    response = Net::HTTP.start(URI(RELEASES_URL).host, 443, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(URI(RELEASES_URL).request_uri, "Accept" => "application/vnd.github+json")
    end
    response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : []
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => e
    Rails.logger.warn "AndroidRelease: could not read releases (#{e.class})"
    []
  end
end
