require "test_helper"

class Rangs::DictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "should create dictionary_entry" do
    assert_difference('DictionaryEntry.count') do
      @rang = rangs(:one)
      post rang_dictionary_entries_url(@rang), params: { dictionary_entry: { translation: SecureRandom.alphanumeric, word_or_phrase: SecureRandom.alphanumeric, rang_id: @rang.id } }
    end

    assert_response :success
  end
end
