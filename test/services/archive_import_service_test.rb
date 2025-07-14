require "test_helper"

class ArchiveImportServiceTest < ActiveSupport::TestCase
  def setup
    @test_media_file = Tempfile.new(['test_media', '.json'])
    @media_file_path = @test_media_file.path
    @service = ArchiveImportService.new(media_file_path: @media_file_path)
  end

  def teardown
    @test_media_file.close
    @test_media_file.unlink
  end

  test "import_next_recording returns nil when media.json doesn't exist" do
    # Delete the temp file to simulate missing media.json
    @test_media_file.close
    @test_media_file.unlink

    assert_nil @service.import_next_recording
  end

  test "import_next_recording creates voice recording from archive" do
    test_media_data = [
      {
        "url" => "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/123",
        "title" => "Turas Siar 123",
        "headline" => "Pap le MTS: Tairngreacht Bhriain Rua",
        "description" => "Test description"
      }
    ]

    File.write(@media_file_path, test_media_data.to_json)

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

    # Check that the item was marked as imported
    updated_data = JSON.parse(File.read(@media_file_path))
    assert updated_data.first['imported']
  end

  test "import_next_recording handles existing recordings" do
    # Create a voice recording with the same generated name
    existing_recording = VoiceRecording.create!(
      title: "Turas Siar 123 - Pap le MTS: Tairngreacht Bhriain Rua",
      owner: users(:one)
    )

    test_media_data = [
      {
        "url" => "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/123",
        "title" => "Turas Siar 123",
        "headline" => "Pap le MTS: Tairngreacht Bhriain Rua",
        "description" => "Test description"
      }
    ]

    File.write(@media_file_path, test_media_data.to_json)

    voice_recording = @service.import_next_recording

    assert_equal existing_recording, voice_recording
    assert_equal 1, VoiceRecording.where(title: "Turas Siar 123 - Pap le MTS: Tairngreacht Bhriain Rua").count

    # Check that the item was marked as imported
    updated_data = JSON.parse(File.read(@media_file_path))
    assert updated_data.first['imported']
  end

  test "import_next_recording returns nil when all items are imported" do
    test_media_data = [
      {
        "url" => "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/123",
        "title" => "Turas Siar 123",
        "headline" => "Pap le MTS: Tairngreacht Bhriain Rua",
        "description" => "Test description",
        "imported" => true
      }
    ]

    File.write(@media_file_path, test_media_data.to_json)

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
end 