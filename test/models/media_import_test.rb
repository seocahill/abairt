require "test_helper"

class MediaImportTest < ActiveSupport::TestCase
  def setup
    @media_import = MediaImport.new(
      url: "https://example.com/test.mp3",
      title: "Test Recording",
      headline: "Test Headline",
      description: "Test Description"
    )
  end

  test "should be valid with valid attributes" do
    assert @media_import.valid?
  end

  test "should require url" do
    @media_import.url = nil
    assert_not @media_import.valid?
    assert_includes @media_import.errors[:url], "can't be blank"
  end

  test "should require title" do
    @media_import.title = nil
    assert_not @media_import.valid?
    assert_includes @media_import.errors[:title], "can't be blank"
  end

  test "should have unique url" do
    @media_import.save!
    duplicate_import = MediaImport.new(
      url: @media_import.url,
      title: "Different Title"
    )
    assert_not duplicate_import.valid?
    assert_includes duplicate_import.errors[:url], "has already been taken"
  end

  test "should default to pending status" do
    @media_import.save!
    assert @media_import.pending?
  end

  test "should mark as imported" do
    @media_import.save!
    @media_import.mark_as_imported!
    assert @media_import.imported?
    assert_not_nil @media_import.imported_at
    assert_nil @media_import.error_message
  end

  test "should mark as skipped" do
    @media_import.save!
    @media_import.mark_as_skipped!("Not needed")
    assert @media_import.skipped?
    assert_equal "Not needed", @media_import.error_message
  end

  test "should mark as failed" do
    @media_import.save!
    @media_import.mark_as_failed!("Network error")
    assert @media_import.failed?
    assert_equal "Network error", @media_import.error_message
  end

  test "should have scopes" do
    # Clear existing records first
    MediaImport.delete_all
    
    MediaImport.create!(url: "https://example.com/1.mp3", title: "Test 1", status: :pending)
    MediaImport.create!(url: "https://example.com/2.mp3", title: "Test 2", status: :imported)
    MediaImport.create!(url: "https://example.com/3.mp3", title: "Test 3", status: :skipped)

    assert_equal 1, MediaImport.pending.count
    assert_equal 1, MediaImport.imported.count
    assert_equal 1, MediaImport.skipped.count
  end
end
