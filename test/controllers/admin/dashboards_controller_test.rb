require "test_helper"

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    ALWAYS_LISTED = %w[/admin/users /admin_emails /admin/locations /admin/questions
      /admin/media_imports /admin/data_dashboard /admin/island_context_playground
      /flipper /jobs /admin/api].freeze

    setup do
      @admin = users(:one)
      @admin.update(role: :admin)
    end

    test "an admin sees a link to every admin page, including Flipper and Jobs" do
      sign_in_as(@admin)
      get admin_root_path
      assert_response :success
      ALWAYS_LISTED.each { |path| assert_select "main a[href=?]", path, true, "missing #{path}" }
    end

    test "flagged pages are linked only when their flag is on" do
      sign_in_as(@admin)
      get admin_root_path
      assert_select "main a[href=?]", "/admin/asr", false
      Flipper.enable(:f75_asr_eval)
      get admin_root_path
      assert_select "main a[href=?]", "/admin/asr"
    end

    test "the admin sidebar on other admin pages links every admin page" do
      sign_in_as(@admin)
      get admin_locations_path
      ALWAYS_LISTED.each { |path| assert_select "nav[aria-label=Admin] a[href=?]", path, true, "missing #{path}" }
      assert_select "nav[aria-label=Admin] a[href=?]", admin_root_path
    end

    test "no admin link leaves the admin area: no Tags (a JSON endpoint) or public Speakers page" do
      sign_in_as(@admin)
      get admin_root_path
      assert_select "a[href=?]", "/tags", false
      assert_select "nav[aria-label=Admin] a[href=?]", "/users", false
      assert_select "[data-admin-menu] a[href=?]", "/users", false
    end

    test "flagged admin pages appear in the sidebar only when their flag is on" do
      sign_in_as(@admin)
      get admin_locations_path
      assert_select "nav[aria-label=Admin] a[href=?]", "/admin/training_progress", false
      Flipper.enable(:f142_training_progress)
      get admin_locations_path
      assert_select "nav[aria-label=Admin] a[href=?]", "/admin/training_progress"
    end

    test "the learner's question screen is not an admin page" do
      sign_in_as(@admin)
      get new_question_path
      assert_response :success
      assert_select "nav[aria-label=Admin]", false
      assert_select "a[href=?][aria-current]", "/admin", false
    end

    test "the sidebar marks the current page, and pages under it" do
      sign_in_as(@admin)
      get admin_users_path
      assert_select "nav[aria-label=Admin] a[aria-current=page]", count: 1, text: "Users"

      get edit_admin_user_path(users(:two))
      assert_select "nav[aria-label=Admin] a[aria-current=page]", count: 1, text: "Users"

      get admin_root_path
      assert_select "nav[aria-label=Admin] a[aria-current=page]", count: 1, text: "Overview"
    end

    test "the top bar's Admin link is marked on admin pages only" do
      sign_in_as(@admin)
      get admin_questions_path
      assert_select "a[href=?][aria-current=true]", "/admin", text: "Admin"
      get home_path
      assert_select "a[href=?][aria-current]", "/admin", false
    end

    test "the phone menu lists the admin pages for admins, on any page" do
      sign_in_as(@admin)
      get home_path
      ALWAYS_LISTED.each { |path| assert_select "[data-admin-menu] a[href=?]", path, true, "missing #{path}" }
      assert_select "[data-admin-menu] a[href=?]", admin_root_path
      assert_select "nav[aria-label=Admin]", false
    end

    test "Flipper and Jobs load as full pages, not through Turbo" do
      sign_in_as(@admin)
      get admin_root_path
      %w[/flipper /jobs].each do |path|
        assert_select "main a[href=?][data-turbo=false]", path
        assert_select "nav[aria-label=Admin] a[href=?][data-turbo=false]", path
      end
      assert_select "nav[aria-label=Admin] a[href=?][data-turbo]", "/admin/users", false
    end

    test "Flipper and Jobs link back to the admin overview" do
      assert_equal "/admin", Flipper::UI.configuration.application_href
      assert_equal "/admin", MissionControl::Jobs.back_to_main_app_path
    end

    test "non-admins are redirected and see no admin links" do
      sign_in_as(users(:two))
      get admin_root_path
      assert_redirected_to root_path
      follow_redirect!
      assert_select "a[href=?]", "/admin", false
      assert_select "nav[aria-label=Admin]", false
      assert_select "[data-admin-menu]", false
    end

    test "the main menu has an Admin link for admins only" do
      get home_path
      assert_select "a[href=?]", "/admin", false
      sign_in_as(users(:two))
      get home_path
      assert_response :success
      assert_select "a[href=?]", "/admin", false
      assert_select "[data-admin-menu]", false
      sign_in_as(@admin)
      get home_path
      assert_select "nav a[href=?]", "/admin"
    end

    private

    def sign_in_as(user)
      user.regenerate_login_token if user.login_token.blank?
      post login_path, params: {token: user.login_token}
    end
  end
end
