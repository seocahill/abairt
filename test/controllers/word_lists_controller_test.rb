require "test_helper"

class WordListsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @word_list = word_lists(:one)
    @user = users(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
    WordList.any_instance.stubs(:generate_vocab).returns({vocabulary: []}.with_indifferent_access)
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
      post word_lists_url, params: { word_list: { user_id: users(:one).id, name: "Prepositions" } }
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

  test "should enqueue GenerateWordListJob when description is present" do
    assert_enqueued_with(job: GenerateWordListJob) do
      post word_lists_url, params: { word_list: { name: 'Test List', description: 'New description' } }
    end

    perform_enqueued_jobs

    assert_response :redirect
    assert_equal 'Word list was successfully created.', flash[:notice]
  end

  test "should not enqueue GenerateWordListJob when description is blank" do
    assert_no_enqueued_jobs do
      post word_lists_url, params: { word_list: { name: 'Test List' } }
    end

    assert_response :redirect
    assert_equal 'Word list was successfully created.', flash[:notice]
  end
end
