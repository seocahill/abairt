require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one) # Assuming you have a users fixture or factory set up
    @user.generate_password_reset_token
    @user.save
  end

  test "should redirect to root path if current user exists on new" do
    post login_path, params: { token: @user.password_reset_token }

    get login_path

    assert_redirected_to root_path
  end

  test "should set session and redirect to user path on successful create" do
    post login_path, params: { token: @user.password_reset_token }

    assert_nil @user.reload.password_reset_token
    assert_equal @user.id, session[:user_id]
    assert_redirected_to user_path(@user)
    assert_equal 'Login successful.', flash[:notice]
  end

  test "should set session and redirect to user path on successful login with token" do
    get login_with_token_url(@user.password_reset_token)

    assert_nil @user.reload.password_reset_token
    assert_equal @user.id, session[:user_id]
    assert_redirected_to user_path(@user)
    assert_equal 'Login successful.', flash[:notice]
  end

  test "should show alert and redirect to login path if user is nil or password reset token is expired on create" do
    post login_path, params: { token: "invalid_token" }

    assert_nil session[:user_id]
    assert_redirected_to login_path
    assert_equal 'Invalid password reset link.', flash[:alert]
  end

  test "should clear session and redirect to root path on destroy" do
    post login_path, params: { token: @user.password_reset_token }
    assert_equal @user.id, session[:user_id]

    delete logout_path

    assert_nil session[:user_id]
    assert_redirected_to root_path
  end
end
