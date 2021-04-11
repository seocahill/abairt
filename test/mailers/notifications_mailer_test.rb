require "test_helper"

class NotificationsMailerTest < ActionMailer::TestCase
  test "ceisteanna" do
    mail = NotificationsMailer.ceisteanna
    assert_equal "Ceisteanna", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "ceád_rang_eile" do
    mail = NotificationsMailer.ceád_rang_eile
    assert_equal "Ceád rang eile", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
