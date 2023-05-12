require "test_helper"

class Rangs::DictionaryEntriesControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get rangs_dictionary_entries_create_url
    assert_response :success
  end
end
