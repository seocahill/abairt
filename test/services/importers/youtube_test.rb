require 'test_helper'

class Importers::YoutubeTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @youtube_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    @short_url = "https://youtu.be/dQw4w9WgXcQ"
  end

  test "valid_youtube_url? recognizes youtube.com URLs" do
    importer = Importers::Youtube.new(@youtube_url)
    assert importer.send(:valid_youtube_url?)
  end

  test "valid_youtube_url? recognizes youtu.be URLs" do
    importer = Importers::Youtube.new(@short_url)
    assert importer.send(:valid_youtube_url?)
  end

  test "valid_youtube_url? rejects invalid URLs" do
    importer = Importers::Youtube.new("https://example.com/video")
    assert_not importer.send(:valid_youtube_url?)
  end

  test "extract_video_id extracts ID from youtube.com URL" do
    importer = Importers::Youtube.new(@youtube_url)
    assert_equal "dQw4w9WgXcQ", importer.send(:extract_video_id)
  end

  test "extract_video_id extracts ID from youtu.be URL" do
    importer = Importers::Youtube.new(@short_url)
    assert_equal "dQw4w9WgXcQ", importer.send(:extract_video_id)
  end

  test "truncate_description limits length and adds source" do
    importer = Importers::Youtube.new(@youtube_url)
    long_description = "a" * 600
    
    result = importer.send(:truncate_description, long_description)
    
    assert result.length < long_description.length
    assert result.include?(@youtube_url)
  end

  test "truncate_description handles blank description" do
    importer = Importers::Youtube.new(@youtube_url)
    
    result = importer.send(:truncate_description, "")
    
    assert_equal "Imported from YouTube: #{@youtube_url}", result
  end

  test "import returns nil for invalid YouTube URL" do
    invalid_importer = Importers::Youtube.new("https://example.com")
    
    result = invalid_importer.import
    
    assert_nil result
  end

  test "import returns nil when yt-dlp is not available" do
    importer = Importers::Youtube.new(@youtube_url)
    importer.stubs(:yt_dlp_available?).returns(false)
    
    result = importer.import
    
    assert_nil result
  end

  test "import_to_record returns false for invalid URL" do
    voice_recording = voice_recordings(:one)
    invalid_importer = Importers::Youtube.new("https://example.com")
    
    result = invalid_importer.import_to_record(voice_recording)
    
    assert_not result
  end

  test "import_to_record returns false when yt-dlp not available" do
    voice_recording = voice_recordings(:one)
    importer = Importers::Youtube.new(@youtube_url)
    importer.stubs(:yt_dlp_available?).returns(false)
    
    result = importer.import_to_record(voice_recording)
    
    assert_not result
  end

  # Integration tests would require yt-dlp to be installed
  # These are more appropriate for system/integration testing
end