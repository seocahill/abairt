require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)
    ApplicationController.any_instance.stubs(:current_user).returns(@user)
  end

  test "shows the form" do
    get edit_password_url
    assert_response :success
  end

  test "sets a password and signs this device in for good" do
    patch password_url, params: {user: {password: "focal-faire-fada", password_confirmation: "focal-faire-fada"}}

    assert_redirected_to new_question_path
    assert @user.reload.authenticate("focal-faire-fada")
    assert cookies[:remember_token].present?
  end

  test "rejects a short password" do
    patch password_url, params: {user: {password: "gearr", password_confirmation: "gearr"}}

    assert_response :unprocessable_entity
    assert_nil @user.reload.password_digest
  end

  test "rejects a mismatched confirmation" do
    patch password_url, params: {user: {password: "focal-faire-fada", password_confirmation: "rud-eile-ar-fad"}}

    assert_response :unprocessable_entity
    assert_nil @user.reload.password_digest
  end

  test "redirects a stranger to the login page" do
    ApplicationController.any_instance.stubs(:current_user).returns(nil)

    get edit_password_url
    assert_redirected_to login_path
  end
end
