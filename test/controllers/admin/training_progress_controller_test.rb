require "test_helper"

module Admin
  class TrainingProgressControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @admin.update(role: :admin)
      sign_in_as(@admin)
    end

    test "shows an admin the report with no flag set" do
      get admin_training_progress_index_path
      assert_response :success
      assert_select "h1", "Training progress"
    end

    test "non-admins are redirected" do
      sign_in_as(users(:two))
      get admin_training_progress_index_path
      assert_redirected_to root_path
    end

    test "signed-out visitors can't see it" do
      delete logout_path
      get admin_training_progress_index_path
      assert_redirected_to root_path
    end

    private

    def sign_in_as(user)
      user.regenerate_login_token if user.login_token.blank?
      post login_path, params: {token: user.login_token}
    end
  end
end
