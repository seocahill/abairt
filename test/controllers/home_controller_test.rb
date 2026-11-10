require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get home_path
    assert_response :success
  end

  test "sticks to the collection: no course or learning tools" do
    get home_path

    assert_no_match(/Mayo Irish course|word ?lists?|Anki|spaced repetition/i, response.body)
  end

  test "describes the Mayo Gaeltacht areas and links the 1926 map" do
    get home_path

    assert_select "h2", text: "The Irish of Mayo"
    assert_select "a[href=?]", "/1926"
  end
end
