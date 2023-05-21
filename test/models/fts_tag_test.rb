require "test_helper"

class FtsTagTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.execute <<-SQL
       -- Bulk insert existing data
      INSERT INTO fts_tags(rowid, name)
      SELECT id, name
      FROM tags;
    SQL
  end

  test "search" do
    query = "connacht"
    assert_equal FtsTag.where("fts_tags match ?", query).first.name, "Connacht Dialect"
  end
end
