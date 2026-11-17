require "test_helper"

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    ALWAYS_LISTED = %w[/admin/users /users /admin_emails /admin/locations /tags /admin/questions
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

    test "the admin menu appears on other admin pages" do
      sign_in_as(@admin)
      get admin_locations_path
      assert_select "nav[aria-label=Admin] a[href=?]", "/flipper"
    end

    test "non-admins are redirected and see no admin links" do
      sign_in_as(users(:two))
      get admin_root_path
      assert_redirected_to root_path
      follow_redirect!
      assert_select "a[href=?]", "/admin", false
      assert_select "nav[aria-label=Admin]", false
    end

    test "the main menu has an Admin link for admins only" do
      get home_path
      assert_select "a[href=?]", "/admin", false
      sign_in_as(users(:two))
      get home_path
      assert_select "a[href=?]", "/admin", false
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
