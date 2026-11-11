# frozen_string_literal: true

require "test_helper"

module Api
  class LoginRequestsControllerTest < ActionDispatch::IntegrationTest
    setup { ActionMailer::Base.deliveries.clear }

    test "emails a sign-in link to an approved account" do
      user = users(:john)

      assert_emails 1 do
        post api_login_requests_path, params: {email: user.email}
      end

      assert_response :accepted
      email = ActionMailer::Base.deliveries.last
      assert_equal [user.email], email.to
      assert_match %r{https?://[^"]+/app_login/}, email.body.to_s
    end

    test "ignores case and spaces in the address" do
      assert_emails 1 do
        post api_login_requests_path, params: {email: "  #{users(:john).email.upcase} "}
      end
    end

    test "answers the same for an address with no account, and sends nothing" do
      assert_no_emails do
        post api_login_requests_path, params: {email: "nobody@example.com"}
      end

      assert_response :accepted
    end

    test "sends nothing to an account that is not approved yet" do
      assert_no_emails do
        post api_login_requests_path, params: {email: users(:five).email}
      end

      assert_response :accepted
    end
  end
end
