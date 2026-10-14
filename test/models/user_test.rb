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

  # The queue picks from `answering` and then sends, so a speaker in it without
  # the address their channel needs would be routed a question with nowhere to
  # put it. Checked per channel, not with a loose "either column is set".
  test "answering includes a WhatsApp speaker with a phone number" do
    assert_includes User.answering, users(:whatsapp_speaker)
  end

  test "answering excludes a WhatsApp speaker with no phone number" do
    speaker = users(:whatsapp_speaker)
    speaker.update!(phone_number: nil, email: "speaker@example.com")

    assert_not_includes User.answering, speaker
  end

  test "answering includes a Telegram speaker with a chat id" do
    speaker = users(:telegram_speaker)
    speaker.update!(answers_questions: true)

    assert_includes User.answering, speaker
  end

  # The chat id arrives when they tap through, so until then there is nowhere to
  # send — even though we hold their phone number.
  test "answering excludes a Telegram speaker who has not tapped through yet" do
    speaker = users(:telegram_speaker)
    speaker.update!(answers_questions: true, telegram_chat_id: nil)

    assert_not_includes User.answering, speaker
  end

  # The admin form posts "" for an untouched field, and "" is not NULL.
  test "a blank telegram chat id is stored as nothing at all" do
    speaker = users(:telegram_speaker)
    speaker.update!(answers_questions: true, telegram_chat_id: "  ")

    assert_nil speaker.reload.telegram_chat_id
    assert_not_includes User.answering, speaker
  end

  test "two speakers can be awaiting a telegram chat at once" do
    first = users(:telegram_speaker)
    first.update!(telegram_chat_id: "")

    second = User.create!(name: "Eile", role: :speaker, phone_number: "353850000001",
      answers_questions: true, channel: :telegram, telegram_chat_id: "", confirmed: true)

    assert_nil first.reload.telegram_chat_id
    assert_nil second.telegram_chat_id
  end

  test "answering excludes anyone not taking questions" do
    speaker = users(:whatsapp_speaker)
    speaker.update!(answers_questions: false)

    assert_not_includes User.answering, speaker
  end
end
