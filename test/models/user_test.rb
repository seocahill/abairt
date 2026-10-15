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

  # The queue picks from `answering` and then sends, so a speaker in it with no
  # chat would be routed a question with nowhere to put it.
  test "answering includes a speaker we hold a chat for" do
    assert_includes User.answering, users(:speaker)
  end

  # The chat id arrives when they follow their invite link. Until then there is
  # nowhere to send, so they are not picked.
  test "answering excludes a speaker who has not followed their link yet" do
    speaker = users(:speaker)
    speaker.update!(telegram_chat_id: nil)

    assert_not_includes User.answering, speaker
  end

  # A phone number is only the fallback way of identifying someone who arrives
  # without a link; it has nothing to do with whether they can be sent to.
  test "answering does not care about a phone number" do
    speaker = users(:speaker)
    speaker.update!(phone_number: nil)

    assert_includes User.answering, speaker
  end

  # The admin form posts "" for an untouched field, and "" is not NULL.
  test "a blank telegram chat id is stored as nothing at all" do
    speaker = users(:speaker)
    speaker.update!(answers_questions: true, telegram_chat_id: "  ")

    assert_nil speaker.reload.telegram_chat_id
    assert_not_includes User.answering, speaker
  end

  test "two speakers can be awaiting a telegram chat at once" do
    first = users(:speaker)
    first.update!(telegram_chat_id: "")

    second = User.create!(name: "Eile", role: :speaker, phone_number: "353850000001",
      answers_questions: true, telegram_chat_id: "", confirmed: true)

    assert_nil first.reload.telegram_chat_id
    assert_nil second.telegram_chat_id
  end

  # The admin form posts "" for an untouched field, and a speaker has no email.
  test "a blank email is stored as nothing at all" do
    speaker = User.create!(name: "Gan Ríomhphost", role: :speaker, email: "  ",
      answers_questions: true, confirmed: true)

    assert_nil speaker.reload.email
  end

  test "two speakers can have no email at once" do
    attrs = {role: :speaker, email: "", answers_questions: true, confirmed: true}
    User.create!(attrs.merge(name: "Duine Amháin"))

    assert_nothing_raised { User.create!(attrs.merge(name: "Duine Eile")) }
  end

  test "answering excludes anyone not taking questions" do
    speaker = users(:speaker)
    speaker.update!(answers_questions: false)

    assert_not_includes User.answering, speaker
  end
end
