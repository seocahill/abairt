require "test_helper"

class ComhrasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @comhra = comhras(:one)
  end

  test "should get index" do
    get comhras_url
    assert_response :success
  end

  test "should get new" do
    get new_comhra_url
    assert_response :success
  end

  test "should create comhra" do
    assert_difference('Comhra.count') do
      post comhras_url, params: { comhra: {  } }
    end

    assert_redirected_to comhra_url(Comhra.last)
  end

  test "should show comhra" do
    get comhra_url(@comhra)
    assert_response :success
  end

  test "should get edit" do
    get edit_comhra_url(@comhra)
    assert_response :success
  end

  test "should update comhra" do
    patch comhra_url(@comhra), params: { comhra: {  } }
    assert_redirected_to comhra_url(@comhra)
  end

  test "should destroy comhra" do
    assert_difference('Comhra.count', -1) do
      delete comhra_url(@comhra)
    end

    assert_redirected_to comhras_url
  end
end
