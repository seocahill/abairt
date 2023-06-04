require "test_helper"

class NotificationsMailerTest < ActionMailer::TestCase
  test "recent messages" do
    mail = NotificationsMailer.with(user: users(:one)).recent_messages
    assert_equal "You have received 1 messages since yesterday", mail.subject
    assert_equal [users(:one).email], mail.to
    assert_equal ['info@abairt.com'], mail.from
  end
end
