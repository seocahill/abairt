require "test_helper"

class NotificationsMailerTest < ActionMailer::TestCase
  test "ceád_rang_eile" do
    mail = NotificationsMailer.with(rang: rangs(:one)).ceád_rang_eile
    assert_equal "An chéad rang eile", mail.subject
    assert_equal rangs(:one).users.pluck(:email), mail.to
    assert_equal ['abairt@abairt.com'], mail.from
  end
end
