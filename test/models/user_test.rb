require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "quality method returns correct quality based on ability" do
    user = users(:one)

    user.ability = "A1"
    assert_equal "low", user.quality

    user.ability = "A2"
    assert_equal "low", user.quality

    user.ability = "B1"
    assert_equal "low", user.quality

    user.ability = "B2"
    assert_equal "fair", user.quality

    user.ability = "C1"
    assert_equal "good", user.quality

    user.ability = "C2"
    assert_equal "good", user.quality

    user.ability = "native"
    assert_equal "excellent", user.quality
  end

  test "all_entries returns all dictionary and spoken dictionary entries" do
    user = users(:one)
    assert_equal user.all_entries, user.dictionary_entries.or(user.spoken_dictionary_entries)
  end

  test "all_recordings returns all voice and spoken voice recordings" do
    user = users(:one)
    assert_equal user.all_recordings, user.voice_recordings.or(user.spoken_voice_recordings)
  end

  test "has_secure_token generates api_token" do
    user = User.new(email: "test@example.com", name: "Test User")
    user.save!
    assert user.api_token.present?
  end

  test "has_secure_token generates login_token" do
    user = User.new(email: "test@example.com", name: "Test User")
    user.save!
    assert user.login_token.present?
  end

  test "regenerate_api_token creates new token" do
    user = users(:one)
    old_token = user.api_token
    user.regenerate_api_token
    user.save!
    refute_equal old_token, user.reload.api_token
  end

  test "regenerate_login_token creates new token" do
    user = users(:one)
    old_token = user.login_token
    user.regenerate_login_token
    user.save!
    refute_equal old_token, user.reload.login_token
  end

  test "with_api_token scope returns users with tokens" do
    user = users(:one)
    assert_includes User.with_api_token, user
  end

  test "search scope finds users by name using FTS" do
    # Ensure FTS is populated
    ActiveRecord::Base.connection.execute <<-SQL
      INSERT OR REPLACE INTO fts_users(rowid, name)
      SELECT id, name FROM users;
    SQL

    user = users(:one)
    results = User.search(user.name.split.first)
    assert_includes results, user
  end

  test "search scope finds users by email" do
    user = users(:one)
    results = User.search(user.email.split("@").first)
    assert_includes results, user
  end

  test "search scope returns all when query is blank" do
    assert_equal User.search(""), User.all
    assert_equal User.search(nil), User.all
  end
end
