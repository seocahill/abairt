require "test_helper"

class ArchiveImportServiceTest < ActiveSupport::TestCase
  def setup
    @service = ArchiveImportService.new
    # Clear any existing MediaImport records
    MediaImport.delete_all
  end

  def teardown
    MediaImport.delete_all
  end

  test "import_next_recording returns nil when no pending MediaImport items exist" do
    assert_nil @service.import_next_recording
  end

  test "import_next_recording creates voice recording from archive" do
    # Create a MediaImport record
    media_import = MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/123",
      title: "Turas Siar 123",
      headline: "Pap le MTS: Tairngreacht Bhriain Rua",
      description: "Test description",
      status: :pending
    )

    # Mock the download to avoid actual network calls
    mock_file = mock
    mock_file.stubs(:content_type).returns('audio/mpeg')
    mock_file.stubs(:read).returns('fake audio content')
    
    URI.stubs(:open).returns(mock_file)

    # Mock duration calculation - stub the method on service to avoid file operations
    @service.stubs(:calculate_duration)
    
    # Mock VoiceRecording duration for assertion
    VoiceRecording.any_instance.stubs(:duration_seconds).returns(120.5)

    voice_recording = @service.import_next_recording

    assert_not_nil voice_recording
    assert_equal "Turas Siar 123 - Pap le MTS: Tairngreacht Bhriain Rua", voice_recording.title
    assert_equal "Test description", voice_recording.description
    assert voice_recording.media.attached?
    assert_equal 120.5, voice_recording.duration_seconds

    # Check that the MediaImport was marked as imported
    media_import.reload
    assert media_import.imported?
    assert_not_nil media_import.imported_at
  end

  test "import_next_recording handles existing recordings" do
    # Create a voice recording with the same generated name
    existing_recording = VoiceRecording.create!(
      title: "Turas Siar 123 - Pap le MTS: Tairngreacht Bhriain Rua",
      owner: users(:one)
    )

    # Create a MediaImport record
    media_import = MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/123",
      title: "Turas Siar 123",
      headline: "Pap le MTS: Tairngreacht Bhriain Rua",
      description: "Test description",
      status: :pending
    )

    voice_recording = @service.import_next_recording

    assert_equal existing_recording, voice_recording
    assert_equal 1, VoiceRecording.where(title: "Turas Siar 123 - Pap le MTS: Tairngreacht Bhriain Rua").count

    # Check that the MediaImport was marked as imported
    media_import.reload
    assert media_import.imported?
  end

  test "import_next_recording returns nil when all items are imported" do
    # Create a MediaImport record that's already imported
    MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/123",
      title: "Turas Siar 123",
      headline: "Pap le MTS: Tairngreacht Bhriain Rua",
      description: "Test description",
      status: :imported
    )

    assert_nil @service.import_next_recording
  end

  test "generate_unique_name combines title and headline" do
    title = "Test Title"
    headline = "Test Headline"
    
    expected = "Test Title - Test Headline"
    assert_equal expected, @service.send(:generate_unique_name, title, headline)
  end

  test "generate_unique_name truncates long names" do
    title = "A" * 200
    headline = "B" * 100
    
    result = @service.send(:generate_unique_name, title, headline)
    assert_equal 255, result.length
    assert result.end_with?("...")
  end

  test "extract_filename returns basename from URL" do
    url = "https://example.com/path/to/file.mp3"
    assert_equal "file.mp3", @service.send(:extract_filename, url)
  end

  test "extract_filename generates random filename when basename is empty" do
    url = "https://example.com/"
    filename = @service.send(:extract_filename, url)
    assert filename.start_with?("archive_")
    assert filename.end_with?(".mp3")
    assert_equal 32, filename.split('_').last.split('.').first.length # hex string length
  end

  test "import_specific_recording processes a specific MediaImport by ID" do
    # Create a MediaImport record
    media_import = MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/456",
      title: "Turas Siar 456",
      headline: "Test Specific Import",
      description: "Test specific description",
      status: :pending
    )

    # Mock the download to avoid actual network calls
    mock_file = mock
    mock_file.stubs(:content_type).returns('audio/mpeg')
    mock_file.stubs(:read).returns('fake audio content')
    
    URI.stubs(:open).returns(mock_file)

    # Mock duration calculation
    @service.stubs(:calculate_duration)
    VoiceRecording.any_instance.stubs(:duration_seconds).returns(180.0)

    voice_recording = @service.import_specific_recording(media_import.id)

    assert_not_nil voice_recording
    assert_equal "Turas Siar 456 - Test Specific Import", voice_recording.title
    assert_equal "Test specific description", voice_recording.description

    # Check that the MediaImport was marked as imported
    media_import.reload
    assert media_import.imported?
  end

  test "import_specific_recording returns nil for non-pending MediaImport" do
    # Create a MediaImport record that's already imported
    media_import = MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/789",
      title: "Turas Siar 789",
      headline: "Already Imported",
      description: "Already imported description",
      status: :imported
    )

    assert_nil @service.import_specific_recording(media_import.id)
  end
end 