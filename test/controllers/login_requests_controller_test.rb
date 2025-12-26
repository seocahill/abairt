# test/controllers/login_requests_controller_test.rb
require 'test_helper'

class LoginRequestsControllerTest < ActionDispatch::IntegrationTest
  test 'should render new template' do
    get new_login_request_path
    assert_response :success
  end

  test 'should redirect to login with notice on create' do
    user = users(:john)
    post login_requests_path, params: { email: user.email }
    assert_redirected_to login_path
    assert_equal 'Check your email for login link.', flash[:notice]
    assert user.reload.login_token.present?
  end

  test 'should redirect to login with notice even if email is incorrect (more secure)' do
    post login_requests_path, params: { email: 'email@doesnot.exist' }
    assert_redirected_to login_path
    assert_equal 'Check your email for login link.', flash[:notice]
  end
end
