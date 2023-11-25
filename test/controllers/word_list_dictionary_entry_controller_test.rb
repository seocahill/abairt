require 'test_helper'

class WordListDictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @word_list_dictionary_entry = word_list_dictionary_entries(:one)
    @user = users(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(@user)
  end

  test "should update word_list_dictionary_entry" do
    patch word_list_dictionary_entry_url(@word_list_dictionary_entry), params: { word_list_dictionary_entry: { dictionary_entry_id: @word_list_dictionary_entry.dictionary_entry_id, word_list_id: @word_list_dictionary_entry.word_list_id } }
    assert_redirected_to @word_list_dictionary_entry.word_list
  end
end
