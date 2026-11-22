# frozen_string_literal: true

require "test_helper"

class AdminPageHelperTest < ActionView::TestCase
  test "the page header has the title, subtitle, back link and actions" do
    html = admin_page_header("Users", subtitle: "Everyone.", back: ["Overview", "/admin"]) { link_to "New", "/new" }
    node = Nokogiri::HTML.fragment(html)

    assert_equal "Users", node.at_css("header h1").text
    assert_equal "Everyone.", node.at_css("header p").text.strip
    assert_equal "/admin", node.at_css("header a[href='/admin']")["href"]
    assert_includes node.at_css("header a[href='/admin']").text, "Overview"
    assert node.at_css("header a[href='/new']")
  end

  test "the page header leaves out what it isn't given" do
    node = Nokogiri::HTML.fragment(admin_page_header("Users"))

    assert_equal "Users", node.at_css("header h1").text
    assert_nil node.at_css("header p")
    assert_nil node.at_css("header a")
  end

  test "a filter link is filled in and marked when it is the current one" do
    current = Nokogiri::HTML.fragment(admin_filter_link("All", "/admin/users", current: true)).at_css("a")
    other = Nokogiri::HTML.fragment(admin_filter_link("Pending", "/admin/users?pending=true", current: false)).at_css("a")

    assert_includes current["class"], "bg-blue-600"
    assert_equal "true", current["aria-current"]
    assert_includes other["class"], "bg-gray-200"
    assert_nil other["aria-current"]
  end

  test "button classes share a shape and differ only in colour" do
    assert_includes admin_button_class(:primary), "bg-blue-600"
    assert_includes admin_button_class(:danger), "bg-red-600"
    assert admin_button_class(:secondary).start_with?(AdminPageHelper::BUTTON_CLASS)
    assert_raises(KeyError) { admin_button_class(:purple) }
  end
end
