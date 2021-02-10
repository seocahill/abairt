require "application_system_test_case"

class DictionaryEntriesTest < ApplicationSystemTestCase
  setup do
    @dictionary_entry = dictionary_entries(:one)
  end

  test "visiting the index" do
    visit dictionary_entries_url
    assert_selector "h1", text: "Dictionary Entries"
  end

  test "creating a Dictionary entry" do
    visit dictionary_entries_url
    click_on "New Dictionary Entry"

    fill_in "Translation", with: @dictionary_entry.translation
    fill_in "Word or phrase", with: @dictionary_entry.word_or_phrase
    click_on "Create Dictionary entry"

    assert_text "Dictionary entry was successfully created"
    click_on "Back"
  end

  test "updating a Dictionary entry" do
    visit dictionary_entries_url
    click_on "Edit", match: :first

    fill_in "Translation", with: @dictionary_entry.translation
    fill_in "Word or phrase", with: @dictionary_entry.word_or_phrase
    click_on "Update Dictionary entry"

    assert_text "Dictionary entry was successfully updated"
    click_on "Back"
  end

  test "destroying a Dictionary entry" do
    visit dictionary_entries_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Dictionary entry was successfully destroyed"
  end
end
