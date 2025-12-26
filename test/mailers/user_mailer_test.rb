# test/mailers/user_mailer_test.rb
require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'login_email' do
    user = users(:john)
    user.regenerate_login_token
    user.save!
    email = UserMailer.login_email(user).deliver_now

    assert_not ActionMailer::Base.deliveries.empty?

    assert_equal [user.email], email.to
    assert_equal 'Login link', email.subject
    assert_equal ["abairt@abairt.com"], email.from
    # Verify email contains login instructions and token information
    email_body = email.body.to_s
    assert email_body.include?("Login Instructions"), "Email should contain login instructions"
    assert email_body.include?("login_with_token") || email_body.include?("token"), "Email should contain login link or token"
    assert email_body.include?("passwordless"), "Email should mention passwordless login"
  end
end
