require "application_system_test_case"

class ComhrasTest < ApplicationSystemTestCase
  setup do
    @comhra = comhras(:one)
  end

  test "visiting the index" do
    visit comhras_url
    assert_selector "h1", text: "Comhras"
  end

  test "creating a Comhra" do
    visit comhras_url
    click_on "New Comhra"

    click_on "Create Comhra"

    assert_text "Comhra was successfully created"
    click_on "Back"
  end

  test "updating a Comhra" do
    visit comhras_url
    click_on "Edit", match: :first

    click_on "Update Comhra"

    assert_text "Comhra was successfully updated"
    click_on "Back"
  end

  test "destroying a Comhra" do
    visit comhras_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Comhra was successfully destroyed"
  end
end
