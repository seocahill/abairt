require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def setup
    users(:one).update_columns(role: User.roles[:admin])
  end

  test "should get new" do
    get new_registration_url
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count", 1) do
      post registrations_url, params: {user: {name: "Test User", email: "test@example.com", about: "About Test User"}}
    end
    assert_equal "Thanks for signing up.", flash[:notice]
    refute User.find_by(email: "test@example.com").confirmed
    assert_redirected_to root_path
  end

  test "should redirect to root path if bot-field is present" do
    post registrations_url, params: {"bot-field": "bot"}
    assert_redirected_to root_path
  end

  test "a submission seconds after the form loaded is treated as a bot" do
    get new_registration_url
    assert_no_difference("User.count") do
      post registrations_url, params: {user: {name: "Fast Bot", email: "fast@example.com"}}
    end
    assert_redirected_to root_path
  end

  test "should not create user with invalid params" do
    assert_no_difference("User.count") do
      post registrations_url, params: {user: {name: "", email: "test@example.com", about: "About Test User"}}
    end
    assert_response :unprocessable_content
    assert_template :new
  end

  test "too many sign-ups from one connection are turned away" do
    RegistrationsController.cache_store.stubs(:increment).returns(11)
    assert_no_difference("User.count") do
      post registrations_url, params: {user: {name: "Eleventh", email: "eleventh@example.com"}}
    end
    assert_redirected_to new_registration_path
    assert_match "Too many sign-ups", flash[:alert]
  end

  test "flag off: the form asks for About and shows the reCAPTCHA box" do
    get new_registration_url
    assert_select "textarea[name=?][required]", "user[about]"
    assert_select "div.g-recaptcha"
    assert_includes response.body, "google.com/recaptcha"
  end

  test "flag off: a failed sign-up shows no error box" do
    post registrations_url, params: {user: {name: "Again", email: users(:two).email}}
    assert_response :unprocessable_content
    assert_select "#signup_errors", count: 0
  end

  test "flag on: the form asks for name and email only" do
    Flipper.enable(:f121_simple_signup)
    get new_registration_url

    assert_select "input[name=?][required]", "user[name]"
    assert_select "input[name=?][required]", "user[email]"
    assert_select "textarea[name=?]", "user[about]", count: 0
    assert_select "div.g-recaptcha", count: 0
    refute_includes response.body, "google.com/recaptcha"
    assert_select "input[name=?]", "bot-field"
    assert_select "input[name=?]", "website"
  end

  test "flag on: name and email create an unconfirmed account and send both emails" do
    Flipper.enable(:f121_simple_signup)
    assert_enqueued_emails 2 do
      assert_difference("User.count", 1) do
        post registrations_url, params: {user: {name: "New Editor", email: "editor@example.com"}}
      end
    end
    user = User.find_by(email: "editor@example.com")
    refute user.confirmed
    assert user.student?
    assert_includes User.student.where.not(confirmed: true), user
    assert_redirected_to root_path
  end

  test "flag on: an email already in use is shown as the reason" do
    Flipper.enable(:f121_simple_signup)
    assert_no_difference("User.count") do
      post registrations_url, params: {user: {name: "Again", email: users(:two).email}}
    end
    assert_response :unprocessable_content
    assert_select "#signup_errors", text: /Email has already been taken/
    assert_select "input[name=?][value=?]", "user[name]", "Again"
  end
end
