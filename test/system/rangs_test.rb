require "application_system_test_case"

class RangsTest < ApplicationSystemTestCase
  setup do
    @rang = rangs(:one)
  end

  test "visiting the index" do
    visit rangs_url
    assert_selector "h1", text: "Rangs"
  end

  test "creating a Rang" do
    visit rangs_url
    click_on "New Rang"

    fill_in "Name", with: @rang.name
    click_on "Create Rang"

    assert_text "Rang was successfully created"
    click_on "Back"
  end

  test "updating a Rang" do
    visit rangs_url
    click_on "Edit", match: :first

    fill_in "Name", with: @rang.name
    click_on "Update Rang"

    assert_text "Rang was successfully updated"
    click_on "Back"
  end

  test "destroying a Rang" do
    visit rangs_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Rang was successfully destroyed"
  end
end
