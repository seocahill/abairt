require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one) # Assuming you have a users fixture or factory set up
    @user.generate_password_reset_token
    @user.save
  end

  test "should redirect to root path if current user exists on new" do
    post login_path, params: { token: @user.password_reset_token }
    follow_redirect!
    # Session should be set after login - verify by checking we can access user page
    get user_path(@user)
    assert_response :success, "Should be logged in after using token"

    get login_path
    # When logged in, login_path should redirect to root_path
    assert_redirected_to root_path
  end

  test "should set session and redirect to user path on successful create" do
    token = @user.password_reset_token
    post login_path, params: { token: token }
    
    # Check redirect before following it
    assert_redirected_to user_path(@user)
    follow_redirect!
    assert_equal 'Login successful.', flash[:notice]
    
    # Verify we can access the user page (proves session is set)
    get user_path(@user)
    assert_response :success
    
    # Verify token was cleared by trying to use it again (should fail)
    post login_path, params: { token: token }
    assert_redirected_to login_path
    assert_equal 'Invalid password reset link.', flash[:alert]
  end

  test "should set session and redirect to user path on successful login with token" do
    token = @user.password_reset_token
    get login_with_token_url(token)
    
    # Check redirect before following it
    assert_redirected_to user_path(@user)
    follow_redirect!
    assert_equal 'Login successful.', flash[:notice]
    
    # Verify we can access the user page (proves session is set)
    get user_path(@user)
    assert_response :success
    
    # Verify token was cleared by trying to use it again (should fail)
    get login_with_token_url(token)
    assert_redirected_to login_path
    assert_equal 'Invalid password reset link.', flash[:alert]
  end

  test "should show alert and redirect to login path if user is nil or password reset token is expired on create" do
    post login_path, params: { token: "invalid_token" }

    assert_nil session[:user_id]
    assert_redirected_to login_path
    assert_equal 'Invalid password reset link.', flash[:alert]
  end

  test "should clear session and redirect to root path on destroy" do
    post login_path, params: { token: @user.password_reset_token }
    follow_redirect!
    # Verify session is set by checking we can access a protected page
    get user_path(@user)
    assert_response :success, "Should be able to access user page when logged in"

    delete logout_path
    # Check redirect before following it
    assert_redirected_to root_path
    follow_redirect!
    # root_path redirects to home_path when not logged in
    follow_redirect!
    # After following redirects, we should be at home page
    assert_response :success
  end
end
