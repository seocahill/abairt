require "test_helper"
require Rails.root.join("db/migrate/20261030120000_drop_word_lists")

class DropWordListsTest < ActiveSupport::TestCase
  setup do
    @migration = DropWordLists.new
    @migration.verbose = false
    # The tables are already dropped in the test schema; bring them back to
    # run the data migration against.
    @migration.down

    @user = users(:one)
    @entry = dictionary_entries(:one)
    @other_entry = dictionary_entries(:two)
  end

  test "a list becomes a tag of the same name on each of its entries" do
    list = create_list("Bia")
    add_to_list(list, @entry)
    add_to_list(list, @other_entry)

    @migration.up

    assert_equal ["Bia"], @entry.reload.tag_list
    assert_equal ["Bia"], @other_entry.reload.tag_list
    assert_equal 2, ActsAsTaggableOn::Tag.find_by!(name: "Bia").taggings_count
  end

  test "lists with the same name share one tag, and an existing tag is reused" do
    ActsAsTaggableOn::Tag.create!(name: "Bia")
    add_to_list(create_list("Bia"), @entry)
    add_to_list(create_list("bia"), @other_entry)

    @migration.up

    assert_equal 1, ActsAsTaggableOn::Tag.where("lower(name) = 'bia'").count
    assert_equal 2, ActsAsTaggableOn::Tag.find_by!(name: "Bia").taggings_count
  end

  test "an entry already carrying the tag is not tagged twice" do
    @entry.tag_list.add("Bia")
    @entry.save!
    add_to_list(create_list("Bia"), @entry)

    @migration.up

    assert_equal 1, ActsAsTaggableOn::Tagging.where(taggable: @entry, context: "tags").count
  end

  test "the auto-created Practice list is not turned into a tag" do
    add_to_list(create_list("Practice"), @entry)

    @migration.up

    assert_empty @entry.reload.tag_list
    assert_nil ActsAsTaggableOn::Tag.find_by(name: "Practice")
  end

  test "entries and practice recordings survive the tables going" do
    list = create_list("Bia")
    join_id = add_to_list(list, @entry)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("audio"), filename: "practice.mp3", content_type: "audio/mpeg")
    attachment_id = insert_attachment(blob, join_id)

    assert_no_difference -> { DictionaryEntry.count } do
      @migration.up
    end

    assert DictionaryEntry.exists?(@entry.id)
    assert ActiveStorage::Attachment.exists?(attachment_id), "the practice recording's attachment was removed"
    assert ActiveStorage::Blob.exists?(blob.id)
    assert_not ActiveRecord::Base.connection.table_exists?(:word_lists)
    assert_not ActiveRecord::Base.connection.table_exists?(:word_list_dictionary_entries)
    assert_not ActiveRecord::Base.connection.table_exists?(:user_lists)
  end

  private

  def create_list(name)
    now = Time.current
    ActiveRecord::Base.connection.insert(
      ActiveRecord::Base.sanitize_sql(["INSERT INTO word_lists (name, user_id, created_at, updated_at) VALUES (?, ?, ?, ?)", name, @user.id, now, now])
    )
  end

  def add_to_list(list_id, entry)
    now = Time.current
    ActiveRecord::Base.connection.insert(
      ActiveRecord::Base.sanitize_sql(["INSERT INTO word_list_dictionary_entries (word_list_id, dictionary_entry_id, created_at, updated_at) VALUES (?, ?, ?, ?)", list_id, entry.id, now, now])
    )
  end

  def insert_attachment(blob, join_id)
    ActiveRecord::Base.connection.insert(
      ActiveRecord::Base.sanitize_sql(["INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at) VALUES ('recordings', 'WordListDictionaryEntry', ?, ?, ?)", join_id, blob.id, Time.current])
    )
  end
end
