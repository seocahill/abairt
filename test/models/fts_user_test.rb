require "test_helper"

class FtsUserTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_users(rowid, name)
      SELECT id, name
      FROM users;
    SQL
  end

  test "search" do
    query = "Seán"
    assert_equal FtsUser.where("fts_users match ?", query).first.name, "Seán Ó Raghallaigh"
  end
end
