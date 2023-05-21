require "test_helper"

class WordListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @word_list = word_lists(:one)
  end

  test "should get index" do
    get word_lists_url
    assert_response :success
  end

  test "should get new" do
    get new_word_list_url
    assert_response :success
  end

  test "should create word_list" do
    assert_difference('WordList.count') do
      post word_lists_url, params: { word_list: { user_id: users(:one).id, name: "Prepositions", description: "List of different prepositions" } }
    end
    assert_redirected_to word_list_url(WordList.last)
  end

  test "should show word_list" do
    get word_list_url(@word_list)
    assert_response :success
  end

  test "should get edit" do
    get edit_word_list_url(@word_list)
    assert_response :success
  end

  test "should update word_list" do
    patch word_list_url(@word_list), params: { word_list: { name: "something else"} }
    assert_redirected_to word_list_url(@word_list)
  end

  test "should destroy word_list" do
    assert_difference('WordList.count', -1) do
      delete word_list_url(@word_list)
    end

    assert_redirected_to word_lists_url
  end
end
