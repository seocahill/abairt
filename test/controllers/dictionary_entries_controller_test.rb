require "test_helper"

class DictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dictionary_entry = dictionary_entries(:one)
  end

  test "should get index" do
    get dictionary_entries_url
    assert_response :success
  end

  test "should get new" do
    get new_dictionary_entry_url
    assert_response :success
  end

  test "should create dictionary_entry" do
    assert_difference('DictionaryEntry.count') do
      post dictionary_entries_url, params: { dictionary_entry: { translation: @dictionary_entry.translation, word_or_phrase: @dictionary_entry.word_or_phrase } }
    end

    assert_redirected_to dictionary_entry_url(DictionaryEntry.last)
  end

  test "should show dictionary_entry" do
    get dictionary_entry_url(@dictionary_entry)
    assert_response :success
  end

  test "should get edit" do
    get edit_dictionary_entry_url(@dictionary_entry)
    assert_response :success
  end

  test "should update dictionary_entry" do
    patch dictionary_entry_url(@dictionary_entry), params: { dictionary_entry: { translation: @dictionary_entry.translation, word_or_phrase: @dictionary_entry.word_or_phrase } }
    assert_redirected_to dictionary_entry_url(@dictionary_entry)
  end

  test "should destroy dictionary_entry" do
    assert_difference('DictionaryEntry.count', -1) do
      delete dictionary_entry_url(@dictionary_entry)
    end

    assert_redirected_to dictionary_entries_url
  end
end
