require "application_system_test_case"

class PasswordResetsTest < ApplicationSystemTestCase
  setup do
    @password_reset = password_resets(:one)
  end

  test "visiting the index" do
    visit password_resets_url
    assert_selector "h1", text: "Password Resets"
  end

  test "creating a Password reset" do
    visit password_resets_url
    click_on "New Password Reset"

    click_on "Create Password reset"

    assert_text "Password reset was successfully created"
    click_on "Back"
  end

  test "updating a Password reset" do
    visit password_resets_url
    click_on "Edit", match: :first

    click_on "Update Password reset"

    assert_text "Password reset was successfully updated"
    click_on "Back"
  end

  test "destroying a Password reset" do
    visit password_resets_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Password reset was successfully destroyed"
  end
end
