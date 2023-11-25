# test/controllers/password_resets_controller_test.rb
require 'test_helper'

class PasswordResetsControllerTest < ActionController::TestCase
  test 'should render new template' do
    get :new
    assert_response :success
    assert_template :new
  end

  test 'should redirect to login with notice on create' do
    user = users(:john)
    post :create, params: { email: user.email }
    assert_redirected_to login_path
    assert_equal 'Check your email for login link.', flash[:notice]
  end

  test 'should redirect to login with notice event if email is incorrect (more secure)' do
    post :create, params: { email: 'email@doesnot.exist' }
    assert_redirected_to login_path
    assert_equal 'Check your email for login link.', flash[:notice]
  end
end
