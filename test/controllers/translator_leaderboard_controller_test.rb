require "test_helper"

class TranslatorLeaderboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index without authentication" do
    get translator_leaderboard_url
    assert_response :success
  end

  test "should display translators ordered by translation count" do
    # Create test users
    translator1 = users(:one)
    translator2 = users(:two)
    
    # Create dictionary entries with translators
    entry1 = DictionaryEntry.create!(
      word_or_phrase: "test1",
      translation: "translation1",
      owner: translator1,
      translator_id: translator1.id
    )
    
    entry2 = DictionaryEntry.create!(
      word_or_phrase: "test2", 
      translation: "translation2",
      owner: translator2,
      translator_id: translator2.id
    )
    
    entry3 = DictionaryEntry.create!(
      word_or_phrase: "test3",
      translation: "translation3", 
      owner: translator1,
      translator_id: translator1.id
    )

    get translator_leaderboard_url
    assert_response :success
    
    # Check that translators are present
    assert_select "h1", text: "Translator Leaderboard"
    
    # Verify translator1 appears before translator2 (higher count)
    response_body = response.body
    translator1_pos = response_body.index(translator1.name)
    translator2_pos = response_body.index(translator2.name)
    
    assert translator1_pos, "Translator1 should be present in response"
    assert translator2_pos, "Translator2 should be present in response"
    assert translator1_pos < translator2_pos, "Translator with more translations should appear first"
  end

  test "should exclude temporary users from leaderboard" do
    temporary_user = User.create!(
      email: "temp@example.com",
      name: "Temporary User",
      password: "password",
      role: :temporary
    )
    
    DictionaryEntry.create!(
      word_or_phrase: "temp_test",
      translation: "temp_translation",
      owner: temporary_user,
      translator_id: temporary_user.id
    )

    get translator_leaderboard_url
    assert_response :success
    
    # Should not include temporary users
    assert_select "div", text: /#{temporary_user.name}/, count: 0
  end

  test "should only show users with translations" do
    # Create user with no translations
    user_no_translations = User.create!(
      email: "notranslations@example.com",
      name: "No Translations User", 
      password: "password",
      role: :student
    )

    get translator_leaderboard_url
    assert_response :success
    
    # Should not show users without translations
    assert_select "div", text: /#{user_no_translations.name}/, count: 0
  end
end