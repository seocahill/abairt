require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
    Current.user = @user
  end

  test "should get index" do
    get users_url
    assert_response :success
  end

  test "should get new" do
    get new_user_url
    assert_redirected_to root_path
  end

  test "should create user" do
    @user.update_columns(role:  User.roles[:admin])
    random_str = SecureRandom.alphanumeric
    assert_difference('User.count', 1) do
      post users_url, params: { user: { email: "#{random_str}@abairt.com", name: random_str, role: "speaker" } }
    end
    assert_redirected_to user_url(User.find_by(name: random_str))
  end

  test "should not directly create teacher or admin" do
    random_str = SecureRandom.alphanumeric
    assert_no_difference('User.count', 1) do
      post users_url, params: { user: { email: "#{random_str}@abairt.com", name: random_str, role: "admin" } }
    end
  end

  test "non-admins cannot change their own role" do
    @user.update_columns(role: User.roles[:student])
    patch user_url(@user), params: { user: { name: "Renamed", role: "speaker" } }

    assert_equal "Renamed", @user.reload.name
    assert_equal "student", @user.role
  end

  test "admins can change a role" do
    other = users(:two)
    @user.update_columns(role: User.roles[:admin])
    patch user_url(other), params: { user: { role: "speaker" } }

    assert_equal "speaker", other.reload.role
  end

  test "should show user" do
    get user_url(@user)
    assert_response :success
  end

  test "should get edit" do
    get edit_user_url(@user)
    assert_response :success
  end

  test "should update user" do
    patch user_url(@user), params: { user: { email: @user.email, name: @user.name } }
    assert_redirected_to user_url(@user)
  end

  test "should not destroy user" do
    assert_difference('User.count', 0) do
      delete user_url(@user)
    end

    assert_redirected_to users_url
  end

  test "creates new speaker and transfers entries from temporary speaker" do
    @user.update_columns(role: User.roles[:admin])
    temp_speaker = users(:temporary)

    entry = dictionary_entries(:with_temp_speaker)
    voice_recording = entry.voice_recording

    random_str = SecureRandom.alphanumeric
    assert_difference('User.count', 1) do  # soft delete temp speaker
      post users_url, params: {
        user: {
          name: "Real Speaker",
          email: "#{random_str}@example.com",
          role: "speaker",
          dialect: "connacht_ó_thuaidh",
          voice: "female",
          replace_speaker_id: temp_speaker.id
        }
      }
    end

    # Check that entries were transferred
    entry.reload
    assert_equal "Real Speaker", entry.speaker.name
  end

  test "temporary users are filtered from general user lists" do
    temp_user = User.create!(
      name: "TEMP_USER",
      email: "temp@temporary.abairt",
      role: :temporary
    )

    get users_url
    assert_response :success
    assert_no_match temp_user.name, @response.body
  end

  test "your own profile links to setting a password" do
    @user.update_columns(password_digest: nil)
    get user_url(@user)
    assert_select "#password_setting a[href=?]", edit_password_path, text: "Set a password"
  end

  test "with a password already set the link says change" do
    @user.update!(password: "a-long-password")
    get user_url(@user)
    assert_select "#password_setting a[href=?]", edit_password_path, text: "Change password"
  end

  test "someone else's profile has no password link" do
    get user_url(users(:two))
    assert_response :success
    assert_select "#password_setting", count: 0
  end

  test "a member's profile leaves out speaker details and language level" do
    get user_url(users(:two))
    assert_response :success
    assert_select "#speaker_details", count: 0
    assert_select "#mapModal", count: 0
    assert_no_match "Language Ability", response.body
  end

  test "a speaker's profile keeps voice, dialect and location" do
    get user_url(users(:four))
    assert_response :success
    assert_select "#speaker_details h3", text: "Dialect"
    assert_select "#speaker_details h3", text: "Location"
    assert_no_match "Language Ability", response.body
  end

  test "a profile links to the person's translations" do
    translator = users(:two)
    2.times do |i|
      DictionaryEntry.create!(word_or_phrase: "focal #{i}", translation: "word #{i}", owner: translator, translator: translator)
    end

    get user_url(translator)
    assert_select "#translations_link a[href=?]", translator_leaderboard_path(translator), text: "2 translations"
  end

  test "a profile without translations has no translations link" do
    get user_url(users(:two))
    assert_select "#translations_link", count: 0
  end

  test "your own profile lets you edit your name" do
    get user_url(@user)
    assert_select "turbo-frame##{dom_id(@user, :name_turbo_frame)} h1#profile_name", text: @user.name
  end

  test "the name edit form has a name field" do
    get edit_user_url(@user), headers: { "Turbo-Frame" => dom_id(@user, :name_turbo_frame) }
    assert_select "turbo-frame##{dom_id(@user, :name_turbo_frame)} input[name='user[name]']"
  end
end
