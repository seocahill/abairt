# test/mailers/user_mailer_test.rb
require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'password_reset_email' do
    user = users(:john)
    user.generate_password_reset_token
    email = UserMailer.password_reset_email(user).deliver_now

    assert_not ActionMailer::Base.deliveries.empty?

    assert_equal [user.email], email.to
    assert_equal 'Password Reset Instructions', email.subject
    assert_equal ["abairt@abairt.com"], email.from
    assert_match user.password_reset_token, email.to_s
  end
end
