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

  test "links the Android app's latest release" do
    get home_path

    assert_select "a[href=?]", "https://github.com/seocahill/abairt/releases/latest/download/abairt-listen.apk", text: "Download the Android app"
  end

  test "flag off: the button shows no version even when one is cached" do
    AndroidRelease.stubs(:latest).returns(AndroidRelease::Version.new(number: "0.4.1", published_on: Date.new(2026, 11, 1)))
    get home_path

    assert_select "a", text: "Download the Android app"
  end

  test "flag on: the button shows the cached version and release date" do
    Flipper.enable(:f126_android_version)
    AndroidRelease.stubs(:latest).returns(AndroidRelease::Version.new(number: "0.4.1", published_on: Date.new(2026, 11, 1)))
    get home_path

    assert_select "a[href=?]", "https://github.com/seocahill/abairt/releases/latest/download/abairt-listen.apk", text: "Download the Android app v0.4.1"
    assert_select "p", text: /released/
  end

  test "flag on but no version known: the original wording" do
    Flipper.enable(:f126_android_version)
    get home_path

    assert_select "a", text: "Download the Android app"
  end
end
