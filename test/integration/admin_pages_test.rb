# frozen_string_literal: true

require "test_helper"

# Every admin page shares one header, one table style and one filter style
# (#183).
class AdminPagesTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin)
    @admin.regenerate_login_token
    post login_path, params: {token: @admin.login_token}
  end

  test "every admin page has exactly one title, from the shared header" do
    Flipper.enable(:f75_asr_eval)
    Flipper.enable(:f142_training_progress)
    (admin_paths + [admin_asr_index_path, admin_training_progress_index_path]).each do |path|
      get path
      assert_response :success, path
      assert_select "main h1", {count: 1}, "#{path} should have one h1"
      assert_select "main > div > header h1", {count: 1}, "#{path} should use the shared page header"
    end
  end

  test "admin tables use the shared table style inside a scrolling box" do
    [admin_users_path, admin_locations_path, admin_media_imports_path, admin_api_index_path,
      admin_questions_path, admin_emails_path].each do |path|
      get path
      assert_select "table", minimum: 1
      assert_select "table:not(.admin-table)", {count: 0}, "#{path} has a table without .admin-table"
      assert_select ".admin-table-wrap > table.admin-table", minimum: 1
    end
  end

  test "filters share one style and mark the current one" do
    get admin_users_path(pending: true, role: "speaker")
    assert_select "a[aria-current=true]", text: "Pending sign-ups"
    assert_select "a[aria-current=true]", text: "Speaker"
    assert_select "a[aria-current=true]", text: "All users", count: 0

    get admin_locations_path(dialect_region: "erris")
    assert_select "a[aria-current=true]", text: "Erris"

    get admin_questions_path
    assert_select "a[aria-current=true]", text: /\AAll/
  end

  test "user filters carry each other and the search" do
    get admin_users_path(role: "speaker", search: "ann")
    assert_select "a[href=?]", admin_users_path(pending: true, role: "speaker", search: "ann"), text: "Pending sign-ups"
    assert_select "form[action=?] input[type=hidden][name=role][value=speaker]", admin_users_path
    assert_select "a[href=?]", admin_users_path(role: "speaker"), text: "Clear"
  end

  test "the shared search box keeps the region filter" do
    get admin_locations_path(dialect_region: "erris")
    assert_select "form[action=?] input[type=hidden][name=dialect_region][value=erris]", admin_locations_path
    assert_select "a", text: "Clear", count: 0
  end

  test "media imports filter by status in the shared style, keeping the search" do
    get admin_media_imports_path(status: "pending", search: "Recording")
    assert_response :success
    assert_select "a[aria-current=true]", text: /\APending \(/
    assert_select "a[href=?]", admin_media_imports_path(status: "failed", search: "Recording"), text: /\AFailed/
    assert_select "a[href=?]", admin_media_imports_path(search: "Recording"), text: /\AAll/
  end

  test "searching media imports and API tokens works (no Postgres-only SQL)" do
    get admin_media_imports_path(search: "test1")
    assert_response :success
    assert_select "td a", text: media_imports(:one).title
    assert_select "td a", text: media_imports(:two).title, count: 0

    @admin.update!(api_token: "token-for-search")
    get admin_api_index_path(search: @admin.email)
    assert_response :success
    assert_select "td", text: @admin.email
  end

  test "destructive admin buttons ask Turbo to confirm first" do
    pending_user = users(:two)
    pending_user.update!(confirmed: false)
    get admin_user_path(pending_user)
    assert_select "form[action=?][data-turbo-confirm]", reject_admin_user_path(pending_user)
    assert_select "form[action=?][data-turbo-confirm]", admin_user_path(pending_user)

    get admin_users_path
    assert_select "input[type=submit][value=?][data-turbo-confirm]", "Bulk Reject Selected"

    get admin_media_import_path(media_imports(:one))
    assert_select "form[action=?][data-turbo-confirm]", admin_media_import_path(media_imports(:one))

    email = emails(:one)
    email.update_column(:sent_at, nil)
    get admin_email_path(email)
    assert_select "form[action=?][data-turbo-confirm]", send_email_admin_email_path(email)
    assert_select "[data-confirm]", count: 0
  end

  test "the data dashboard loads when entries have no region times" do
    @admin.update!(dialect: :acaill, voice: :female)
    assert DictionaryEntry.where(speaker: @admin, region_start: nil).exists?

    get admin_data_dashboard_path
    assert_response :success
  end

  private

  def admin_paths
    user = users(:two)
    email = emails(:one)
    location = locations(:belmullet)
    media_import = media_imports(:one)
    [
      admin_root_path, admin_users_path, admin_user_path(user), new_admin_user_path, edit_admin_user_path(user),
      admin_emails_path, new_admin_email_path, admin_email_path(email), edit_admin_email_path(email),
      admin_locations_path, edit_admin_location_path(location), admin_questions_path,
      admin_media_imports_path, new_admin_media_import_path, admin_media_import_path(media_import),
      edit_admin_media_import_path(media_import), admin_data_dashboard_path,
      admin_island_context_playground_path, admin_api_index_path
    ]
  end
end
