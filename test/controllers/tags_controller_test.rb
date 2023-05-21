require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    setup_search
    get tags_url, params: { search: "connacht" }, as: :json
    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal 1, json_response.length
    assert_equal "Connacht Dialect", json_response[0]['name']
  end

  def setup_search
    ActiveRecord::Base.connection.execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_tags(rowid, name)
      SELECT id, name
      FROM tags;
    SQL
  end
end
