require "application_system_test_case"

class LoginRequestsTest < ApplicationSystemTestCase
  test "requesting a login link" do
    visit login_requests_new_path
    assert_selector "h2", text: "Request Login Link"
    
    fill_in "email", with: users(:john).email
    click_button "Send Login Link"
    
    assert_text "Check your email for login link."
  end
end
