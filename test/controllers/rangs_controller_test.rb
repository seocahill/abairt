require "test_helper"

class RangsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @rang = rangs(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "should get index" do
    get rangs_url
    assert_response :success
  end

  test "should get new" do
    users(:one).update_columns(role: User.roles[:teacher])
    get new_rang_url
    assert_response :success
  end

  test "should create rang" do
    users(:one).update_columns(role: User.roles[:teacher])
    assert_difference('Rang.count') do
      post rangs_url, params: { rang: { name: @rang.name } }
    end

    assert_redirected_to rangs_url
  end

  test "should show rang" do
    get rang_url(@rang)
    assert_response :success
  end

  test "should get edit" do
    get edit_rang_url(@rang)
    assert_response :success
  end

  test "should update rang" do
    assert_equal @rang.teacher, users(:one)
    patch rang_url(@rang), params: { rang: { name: @rang.name } }
    assert_redirected_to rangs_url(chat: @rang.id)
  end

  test "should destroy rang" do
    assert_difference('Rang.count', -1) do
      delete rang_url(@rang)
    end

    assert_redirected_to rangs_url
  end
end
