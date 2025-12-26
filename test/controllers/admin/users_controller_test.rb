# frozen_string_literal: true

require 'test_helper'

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    def setup
      @admin = users(:one)
      @admin.update(role: :admin)
      @pending_user = users(:five)
      @pending_user.update(confirmed: false)
      sign_in_as(@admin)
    end

    test "should require admin access" do
      non_admin = users(:two)
      sign_in_as(non_admin)
      get admin_users_path
      assert_redirected_to root_path
    end

    test "should list users" do
      get admin_users_path
      assert_response :success
    end

    test "should filter pending users" do
      get admin_users_path(pending: true)
      assert_response :success
    end

    test "should search users by name" do
      # Ensure FTS is populated
      ActiveRecord::Base.connection.execute <<-SQL
        INSERT OR REPLACE INTO fts_users(rowid, name)
        SELECT id, name FROM users;
      SQL

      get admin_users_path(search: @pending_user.name.split.first)
      assert_response :success
      assert_match @pending_user.name, response.body
    end

    test "should search users by email" do
      get admin_users_path(search: @pending_user.email)
      assert_response :success
      assert_match @pending_user.email, response.body
    end

    test "should show user" do
      get admin_user_path(@pending_user)
      assert_response :success
    end

    test "should get edit" do
      get edit_admin_user_path(@pending_user)
      assert_response :success
    end

    test "should update user" do
      patch admin_user_path(@pending_user), params: { user: { name: "Updated Name", email: @pending_user.email } }
      assert_redirected_to admin_user_path(@pending_user)
      assert_equal "Updated Name", @pending_user.reload.name
    end

    test "should not update user with invalid data" do
      patch admin_user_path(@pending_user), params: { user: { name: "", email: @pending_user.email } }
      assert_response :unprocessable_entity
    end

    test "should approve user" do
      post approve_admin_user_path(@pending_user)
      assert_redirected_to admin_user_path(@pending_user)
      assert @pending_user.reload.confirmed?
    end

    test "should reject user" do
      assert_difference 'User.count', -1 do
        post reject_admin_user_path(@pending_user)
      end
      assert_redirected_to admin_users_path(pending: true)
    end

    test "should bulk approve users" do
      user2 = users(:john)
      user2.update(confirmed: false)
      post bulk_approve_admin_users_path, params: { user_ids: [@pending_user.id, user2.id] }
      assert_redirected_to admin_users_path(pending: true)
      assert @pending_user.reload.confirmed?
      assert user2.reload.confirmed?
    end

    test "should bulk reject users" do
      user2 = users(:john)
      user2.update(confirmed: false)
      assert_difference 'User.count', -2 do
        post bulk_reject_admin_users_path, params: { user_ids: [@pending_user.id, user2.id] }
      end
      assert_redirected_to admin_users_path(pending: true)
    end

    test "should generate API token for user" do
      @user = users(:two)
      @user.update_column(:api_token, nil)
      post generate_api_token_admin_user_path(@user)
      assert_redirected_to admin_user_path(@user)
      assert @user.reload.api_token.present?
    end

    test "should regenerate API token" do
      @user = users(:two)
      old_token = @user.api_token || "old_token"
      @user.update_column(:api_token, old_token)
      post regenerate_api_token_admin_user_path(@user)
      assert_redirected_to admin_user_path(@user)
      refute_equal old_token, @user.reload.api_token
    end

    test "should revoke API token" do
      @user = users(:two)
      @user.regenerate_api_token
      @user.save!
      post revoke_api_token_admin_user_path(@user)
      assert_redirected_to admin_user_path(@user)
      assert_nil @user.reload.api_token
    end

    private

    def sign_in_as(user)
      unless user.login_token.present?
        user.regenerate_login_token
        user.save!
      end
      post login_path, params: { token: user.login_token }
    end
  end
end

