require "test_helper"

class DictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @dictionary_entry = dictionary_entries(:one)
    ApplicationController.any_instance.stubs(:current_user).returns(users(:one))
  end

  test "should get index" do
    get dictionary_entries_url
    assert_response :success
  end

  test "should search index" do
    setup_search
    get dictionary_entries_url, params: { search: "chaoí" }, as: :json
    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 1, json_response.length
    assert_equal "Cén chaoi gur éirigh leat", json_response[0]['word_or_phrase']
    # Add more assertions as needed
  end

  test "should get new" do
    get new_dictionary_entry_url
    assert_response :success
  end

  test "should create dictionary_entry" do
    assert_difference('DictionaryEntry.count') do
      post dictionary_entries_url, params: { dictionary_entry: { notes: "notes", translation: "something", word_or_phrase: "rud éicint" } }
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
    patch dictionary_entry_url(@dictionary_entry), params: { dictionary_entry: { notes: @dictionary_entry.notes, translation: @dictionary_entry.translation, word_or_phrase: @dictionary_entry.word_or_phrase } }
    assert_redirected_to dictionary_entry_url(@dictionary_entry)
  end

  test "should destroy dictionary_entry" do
    assert_difference('DictionaryEntry.count', -1) do
      delete dictionary_entry_url(@dictionary_entry)
    end

    assert_redirected_to dictionary_entries_url
  end

  def setup_search
    ActiveRecord::Base.connection.execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_dictionary_entries(rowid, translation, word_or_phrase)
      SELECT id, translation, word_or_phrase
      FROM dictionary_entries;
    SQL
  end
end
