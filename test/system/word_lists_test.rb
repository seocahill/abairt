require "application_system_test_case"

class WordListsTest < ApplicationSystemTestCase
  setup do
    @word_list = word_lists(:one)
  end

  test "visiting the index" do
    visit word_lists_url
    assert_selector "h1", text: "Word Lists"
  end

  test "creating a Word list" do
    visit word_lists_url
    click_on "New Word List"

    click_on "Create Word list"

    assert_text "Word list was successfully created"
    click_on "Back"
  end

  test "updating a Word list" do
    visit word_lists_url
    click_on "Edit", match: :first

    click_on "Update Word list"

    assert_text "Word list was successfully updated"
    click_on "Back"
  end

  test "destroying a Word list" do
    visit word_lists_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Word list was successfully destroyed"
  end
end
