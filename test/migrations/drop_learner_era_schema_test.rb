require "test_helper"
require Rails.root.join("db/migrate/20261122200000_drop_learner_era_schema")

class DropLearnerEraSchemaTest < ActiveSupport::TestCase
  DROPPED_TABLES = %i[learning_progresses learning_sessions items courses articles seomras grupas].freeze
  DROPPED_COLUMNS = %w[token master_id grupa_id].freeze
  COUNTED = %w[User.count DictionaryEntry.count VoiceRecording.count ActiveStorage::Attachment.count
    ActiveStorage::Blob.count ActsAsTaggableOn::Tag.count ActsAsTaggableOn::Tagging.count].freeze

  setup do
    @migration = DropLearnerEraSchema.new
    @migration.verbose = false
    # The test schema is already past this migration; bring the old tables
    # and columns back to run it against.
    @migration.down

    @user = users(:one)
    @entry = dictionary_entries(:one)
  end

  test "drops the learner-era tables and the unused user columns" do
    @migration.up

    DROPPED_TABLES.each do |table|
      assert_not connection.table_exists?(table), "#{table} is still there"
    end
    assert_empty DROPPED_COLUMNS & connection.columns(:users).map(&:name)
    assert_not connection.index_exists?(:users, :token)
  end

  test "rows left in the old tables do not stop it, and nothing else is touched" do
    fill_old_tables
    connection.execute("UPDATE users SET token = 'old', master_id = 1, grupa_id = 1 WHERE id = #{@user.id}")
    @entry.update!(tag_list: ["Farming life"])
    users_before = kept_user_rows

    assert_no_difference COUNTED do
      @migration.up
    end

    User.reset_column_information
    assert_equal users_before, kept_user_rows
    assert_equal ["Farming life"], @entry.reload.tag_list
  end

  test "ids of deleted users are not handed out again" do
    newest = User.create!(name: "Newest Account", email: "newest@example.com", role: :student)
    newest.destroy!

    @migration.up
    User.reset_column_information

    assert_operator User.create!(name: "Next Account", email: "next@example.com", role: :student).id, :>, newest.id
  end

  test "people who were there before stay searchable" do
    connection.execute("INSERT INTO fts_users(fts_users) VALUES('rebuild')")

    @migration.up

    assert_includes name_matches(@user.name.split.first), @user.id
    assert_nothing_raised { connection.execute("INSERT INTO fts_users(fts_users, rank) VALUES('integrity-check', 1)") }
  end

  test "name search still follows new and renamed users afterwards" do
    @migration.up
    User.reset_column_information

    user = User.create!(name: "Zebedee Quillfeather", email: "zq@example.com", role: :student)
    assert_includes name_matches("Zebedee"), user.id

    user.update!(name: "Bartholomew Quillfeather")
    assert_includes name_matches("Bartholomew"), user.id
    assert_not_includes name_matches("Zebedee"), user.id

    user.destroy!
    assert_not_includes name_matches("Bartholomew"), user.id
  end

  private

  def connection
    ActiveRecord::Base.connection
  end

  # Every column that stays, for every user.
  def kept_user_rows
    connection.select_all("SELECT * FROM users ORDER BY id").to_a.map { |row| row.except(*DROPPED_COLUMNS) }
  end

  def name_matches(word)
    FtsUser.where("fts_users MATCH ?", word).pluck(:rowid)
  end

  def fill_old_tables
    now = Time.current
    insert(:grupas, ainm: "Old group", created_at: now, updated_at: now)
    rang = insert(:rangs, name: "Old class", user_id: @user.id, created_at: now, updated_at: now)
    insert(:seomras, user_id: @user.id, rang_id: rang, created_at: now, updated_at: now)
    insert(:articles, title: "Old article", user_id: @user.id, created_at: now, updated_at: now)
    course = insert(:courses, name: "Old course", user_id: @user.id, created_at: now, updated_at: now)
    insert(:items, name: "Old item", course_id: course, itemable_type: "DictionaryEntry", itemable_id: @entry.id, created_at: now, updated_at: now)
    session = insert(:learning_sessions, user_id: @user.id, learnable_type: "Course", learnable_id: course, created_at: now, updated_at: now)
    insert(:learning_progresses, learning_session_id: session, dictionary_entry_id: @entry.id, created_at: now, updated_at: now)
  end

  def insert(table, attributes)
    columns = attributes.keys.join(", ")
    placeholders = Array.new(attributes.size, "?").join(", ")
    sql = ActiveRecord::Base.sanitize_sql(["INSERT INTO #{table} (#{columns}) VALUES (#{placeholders})", *attributes.values])
    connection.insert(sql)
  end
end
