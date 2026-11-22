# frozen_string_literal: true

require "test_helper"

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
      patch admin_user_path(@pending_user), params: {user: {name: "Updated Name", email: @pending_user.email}}
      assert_redirected_to admin_user_path(@pending_user)
      assert_equal "Updated Name", @pending_user.reload.name
    end

    test "should not update user with invalid data" do
      patch admin_user_path(@pending_user), params: {user: {name: "", email: @pending_user.email}}
      assert_response :unprocessable_entity
    end

    test "should approve user" do
      post approve_admin_user_path(@pending_user)
      assert_redirected_to admin_user_path(@pending_user)
      assert @pending_user.reload.confirmed?
    end

    test "should reject user" do
      get admin_users_path(pending: true)
      assert_difference "User.count", -1 do
        post reject_admin_user_path(@pending_user)
      end
      assert_redirected_to admin_users_path(pending: true)
    end

    test "should bulk approve users" do
      get admin_users_path(pending: true)
      user2 = users(:john)
      user2.update(confirmed: false)
      post bulk_approve_admin_users_path, params: {user_ids: [@pending_user.id, user2.id]}
      assert_redirected_to admin_users_path(pending: true)
      assert @pending_user.reload.confirmed?
      assert user2.reload.confirmed?
    end

    test "should bulk reject users" do
      get admin_users_path(pending: true)
      user2 = users(:john)
      user2.update(confirmed: false)
      assert_difference "User.count", -2 do
        post bulk_reject_admin_users_path, params: {user_ids: [@pending_user.id, user2.id]}
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

    # A speaker has no email, no password and never sees a web page, so this
    # form is the only way one can exist. Before it, the answer was the Rails
    # console on production.
    test "creates a speaker who is not routable until they follow their link" do
      assert_no_difference -> { User.answering.count } do
        post admin_users_path, params: {user: {
          name: "Pápa",
          role: "speaker",
          phone_number: "353 86 123 9999",
          answers_questions: "1",
          confirmed: "1"
        }}
      end

      speaker = User.order(:created_at).last
      assert_redirected_to admin_user_path(speaker)
      assert_nil speaker.email
      assert_equal "353861239999", speaker.phone_number
      assert speaker.answers_questions?
      # No chat id until they follow the link, so nothing is routed to them yet.
      assert_not_includes User.answering, speaker
    end

    # The point of invite links: a Telegram speaker needs neither an email nor a
    # phone number, because the link identifies them.
    test "creates a Telegram speaker with no email and no phone number" do
      post admin_users_path, params: {user: {
        name: "Pápa",
        role: "speaker",
        answers_questions: "1",
        confirmed: "1"
      }}

      speaker = User.order(:created_at).last
      assert_redirected_to admin_user_path(speaker)
      assert_nil speaker.email
      assert_nil speaker.phone_number
      assert speaker.telegram_invite_token.present?
      assert_not_includes User.answering, speaker
    end

    test "still requires an email from anyone who is not a speaker" do
      assert_no_difference -> { User.count } do
        post admin_users_path, params: {user: {name: "Gan Ríomhphost", role: "student"}}
      end

      assert_response :unprocessable_entity
    end

    # Fixtures and any row not created through the model have no token, so a
    # speaker who predates invite links could otherwise never be invited.
    test "issues an invite link for a speaker that has none" do
      speaker = users(:speaker)
      speaker.update!(answers_questions: true, telegram_invite_token: nil)

      assert_changes -> { speaker.reload.telegram_invite_token } do
        post telegram_invite_admin_user_path(speaker)
      end

      assert_redirected_to admin_user_path(speaker)
    end

    test "issuing a new link invalidates the old one" do
      speaker = users(:speaker)
      speaker.update!(answers_questions: true)
      speaker.regenerate_telegram_invite_token
      old_token = speaker.telegram_invite_token

      post telegram_invite_admin_user_path(speaker)

      assert_not_equal old_token, speaker.reload.telegram_invite_token
    end

    test "re-renders the form when the user is invalid" do
      assert_no_difference -> { User.count } do
        post admin_users_path, params: {user: {name: "", role: "student"}}
      end

      assert_response :unprocessable_entity
    end

    test "non-admins cannot create users" do
      sign_in_as(users(:two))

      assert_no_difference -> { User.count } do
        post admin_users_path, params: {user: {name: "Sneaky", role: "student", email: "s@example.com"}}
      end
    end

    test "should get the new user form" do
      get new_admin_user_path
      assert_response :success
    end

    test "opens on the members tab" do
      users(:john).update!(role: :student)
      get admin_users_path

      assert_response :success
      assert_select "nav[aria-label='Kinds of user'] a[aria-current='true']", text: "Members"
      assert_select "td a", text: users(:john).name
      assert_select "td a", text: users(:speaker).name, count: 0
      assert_select "input[value='Bulk Approve Selected']"
      assert_select "a", text: "New member"
    end

    test "the speakers tab lists speakers with their own columns and no bulk actions" do
      get admin_users_path(kind: "speakers")

      assert_response :success
      assert_select "td a", text: users(:speaker).name
      assert_select "td a", text: users(:john).name, count: 0
      assert_select "th", text: "Dialect"
      assert_select "th", text: "Email", count: 0
      assert_select "input[value='Bulk Approve Selected']", count: 0
      assert_select "a[href='#{new_admin_user_path(kind: "speakers")}']", text: "New speaker"
    end

    test "shows whether a speaker's Telegram is connected" do
      users(:speaker).update!(answers_questions: true, telegram_chat_id: "4242")
      users(:second_speaker).update!(answers_questions: true, telegram_chat_id: nil)

      get admin_users_path(kind: "speakers")

      assert_select "span", text: "Connected"
      assert_select "span", text: "Not connected"
    end

    test "the staff tab lists admins with their token actions" do
      get admin_users_path(kind: "staff")

      assert_response :success
      assert_select "td a", text: users(:admin).name
      assert_select "td a", text: users(:speaker).name, count: 0
      assert_select "th", text: "API Token"
      assert_select "a", text: "New staff or API user"
    end

    test "only the other tab lists the unnamed speakers diarisation leaves" do
      get admin_users_path(kind: "other")
      assert_select "td a", text: users(:temporary).name

      get admin_users_path(kind: "all")
      assert_select "td a", text: users(:temporary).name, count: 0
      assert_select "td a", text: users(:speaker).name
    end

    test "search stays within the tab" do
      get admin_users_path(kind: "speakers", search: users(:john).email)

      assert_response :success
      assert_select "td a", text: users(:john).name, count: 0
      assert_select "input[type=hidden][name=kind][value=speakers]"
    end

    test "an unknown tab falls back to members" do
      get admin_users_path(kind: "nonsense")

      assert_select "nav[aria-label='Kinds of user'] a[aria-current='true']", text: "Members"
    end

    test "rejecting from the pending members tab returns to it" do
      get admin_users_path(kind: "members", pending: true)
      post reject_admin_user_path(@pending_user)

      assert_redirected_to admin_users_path(kind: "members", pending: true)
    end

    test "the new form starts with the role of the kind asked for" do
      get new_admin_user_path(kind: "staff")
      assert_select "select[name='user[role]'] option[selected][value=api_user]"
      assert_select "input[name='user[answers_questions]']", count: 0

      get new_admin_user_path(kind: "members")
      assert_select "select[name='user[role]'] option[selected][value=student]"

      get new_admin_user_path
      assert_select "select[name='user[role]'] option[selected][value=speaker]"
      assert_select "input[name='user[answers_questions]']"
    end

    test "the role list still offers every role, grouped by kind" do
      get edit_admin_user_path(users(:john))

      assert_select "select[name='user[role]'] optgroup", count: User::KINDS.size
      assert_select "select[name='user[role]'] option", count: User.roles.size
    end

    test "a member's form and page leave out speaker fields" do
      member = users(:john)
      member.update!(role: :student)

      get edit_admin_user_path(member)
      assert_select "select[name='user[dialect]']", count: 0
      assert_select "input[name='user[answers_questions]']", count: 0
      assert_select "label", text: "Level of Irish"

      get admin_user_path(member)
      assert_select "h3", text: "Dialect", count: 0
      assert_select "h3", text: "API Token"
    end

    test "a speaker's form and page carry the speaker fields" do
      get edit_admin_user_path(users(:speaker))
      assert_select "select[name='user[dialect]']"
      assert_select "input[name='user[answers_questions]']"

      get admin_user_path(users(:speaker))
      assert_select "h3", text: "Dialect"
    end

    test "a speaker with no token has no token section, one with a token keeps it" do
      speaker = users(:speaker)
      speaker.update_column(:api_token, nil)
      get admin_user_path(speaker)
      assert_select "h3", text: "API Token", count: 0

      speaker.update_column(:api_token, "speakertoken123")
      get admin_user_path(speaker)
      assert_select "h3", text: "API Token"
      assert_select "button", text: "Revoke Token"
    end

    test "a staff member's form has neither speaker nor member fields" do
      get edit_admin_user_path(users(:admin))

      assert_select "select[name='user[dialect]']", count: 0
      assert_select "textarea[name='user[about]']", count: 0
      assert_select "select[name='user[role]']"
    end

    test "editing a member leaves the fields their form does not show alone" do
      member = users(:john)
      member.update!(role: :student, dialect: :acaill)

      patch admin_user_path(member), params: {user: {name: "John", email: member.email, role: "student"}}

      assert_equal "acaill", member.reload.dialect
    end

    test "a member can still be moved to another kind" do
      member = users(:john)
      member.update!(role: :student)

      patch admin_user_path(member), params: {user: {name: member.name, email: member.email, role: "admin"}}

      assert member.reload.admin?
    end

    private

    def sign_in_as(user)
      if user.login_token.blank?
        user.regenerate_login_token
        user.save!
      end
      post login_path, params: {token: user.login_token}
    end
  end
end
