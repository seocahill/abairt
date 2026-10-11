require "test_helper"

# The password route and the cookie that keeps you signed in. Between them they
# are what make "open the app, record, send" possible — a lapsed session would
# otherwise send the learner off to find a login link in their email.
class SessionsControllerPasswordTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    @user.update!(password: "sruthan-gaeilge", password_confirmation: "sruthan-gaeilge")
  end

  test "signs in with an email and password" do
    post login_url, params: {email: @user.email, password: "sruthan-gaeilge"}

    assert_redirected_to new_question_path
    assert_equal @user.id, session[:user_id]
  end

  test "rejects a wrong password" do
    post login_url, params: {email: @user.email, password: "micheart"}

    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "rejects an unknown email" do
    post login_url, params: {email: "nobody@example.com", password: "sruthan-gaeilge"}

    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "will not sign in a user who has no password set" do
    post login_url, params: {email: users(:three).email, password: "pé rud"}

    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "signing in sets a remember cookie and a fresh token" do
    assert_changes -> { @user.reload.remember_token } do
      post login_url, params: {email: @user.email, password: "sruthan-gaeilge"}
    end

    assert cookies[:remember_token].present?
  end

  test "the cookie resurrects the session after it lapses" do
    post login_url, params: {email: @user.email, password: "sruthan-gaeilge"}

    # What a phone does days later: cookie survives, session does not.
    expire_session_cookie

    get new_question_url
    assert_response :success
    assert_equal @user.id, session[:user_id]
  end

  test "signing out clears the cookie and invalidates the old token" do
    post login_url, params: {email: @user.email, password: "sruthan-gaeilge"}
    was = @user.reload.remember_token

    delete logout_url

    assert_nil session[:user_id]
    assert cookies[:remember_token].blank?
    assert_not_equal was, @user.reload.remember_token
  end

  test "a stale cookie is discarded rather than trusted" do
    post login_url, params: {email: @user.email, password: "sruthan-gaeilge"}
    @user.regenerate_remember_token
    expire_session_cookie

    get new_question_url

    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "the magic link token still works" do
    token = users(:one).login_token
    post login_url, params: {token: token}

    assert_equal users(:one).id, session[:user_id]
  end

  private

  # Drops the session cookie and keeps the rest, which is what a browser restart
  # does. Resetting the whole integration session would also lose the jar's host
  # and silently stop sending the remember cookie at all.
  def expire_session_cookie
    cookies.delete(Rails.application.config.session_options[:key])
  end
end
