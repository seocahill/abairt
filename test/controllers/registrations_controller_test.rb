require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    users(:one).update_columns(role: User.roles[:admin])
  end

  test "should get new" do
    get new_registration_url
    assert_response :success
  end

  test "should create user" do
    assert_difference('User.count', 1) do
      post registrations_url, params: { user: { name: 'Test User', email: 'test@example.com', about: 'About Test User' } }
    end
    assert_equal 'Thanks for signing up.', flash[:notice]
    refute User.find_by(email: 'test@example.com').confirmed
    assert_redirected_to root_path
  end

  test "should not create user with invalid params" do
    assert_no_difference('User.count') do
      post registrations_url, params: { user: { name: '', email: 'test@example.com', about: 'About Test User' } }
    end
    assert_response :success
    assert_template :new
  end
end
