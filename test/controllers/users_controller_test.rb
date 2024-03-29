require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "should get index" do
    get users_url
    assert_response :success
  end

  test "should get new" do
    get new_user_url
    assert_response :success
  end

  test "should create user" do
    random_str = SecureRandom.alphanumeric

    assert_difference('User.count') do
      post users_url, params: { user: { email: "#{random_str}@abairt.com", name: random_str, password_digest: random_str } }
    end

    assert_redirected_to user_url(User.last)
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
    patch user_url(@user), params: { user: { email: @user.email, name: @user.name, password_digest: @user.password_digest } }
    assert_redirected_to user_url(@user)
  end

  test "should not destroy user" do
    assert_difference('User.count', 0) do
      delete user_url(@user)
    end

    assert_redirected_to users_url
  end
end
