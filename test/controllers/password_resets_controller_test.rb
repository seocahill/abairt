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
    assert_equal 'Password reset instructions have been sent to your email.', flash[:notice]
  end

  test 'should render new template with alert on create' do
    post :create, params: { email: 'nonexistent@example.com' }
    assert_template :new
    assert_equal 'Email address not found.', flash[:alert]
  end

  test 'should render edit template' do
    user = users(:john)
    user.generate_password_reset_token
    user.save
    get :edit, params: { token: user.password_reset_token }
    assert_response :success
    assert_template :edit
  end

  test 'should redirect to login with alert on invalid edit token' do
    get :edit, params: { token: 'invalid_token' }
    assert_redirected_to login_path
    assert_equal 'Invalid password reset link.', flash[:alert]
  end

  test 'should redirect to login with alert on expired edit token' do
    user = users(:john)
    user.generate_password_reset_token
    user.password_reset_sent_at = 2.hours.ago
    user.save
    get :edit, params: { token: user.password_reset_token }
    assert_redirected_to login_path
    assert_equal 'Invalid password reset link.', flash[:alert]
  end

  test 'should redirect to login with notice on successful update' do
    user = users(:john)
    user.generate_password_reset_token
    user.save
    patch :update, params: { token: user.password_reset_token, user: { password: 'new_password', password_confirmation: 'new_password' } }
    assert_redirected_to login_path
    assert_equal 'Your password has been successfully reset. Please log in with your new password.', flash[:notice]
  end

  test 'should render edit template with errors on unsuccessful update' do
    user = users(:john)
    user.generate_password_reset_token
    user.save
    patch :update, params: { token: user.password_reset_token, user: { password: 'new_password', password_confirmation: 'wrong_password' } }
    assert_template :edit
    assert_select 'h2', '1 error prohibited this user from being saved:'
  end
end
