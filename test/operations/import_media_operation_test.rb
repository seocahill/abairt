# frozen_string_literal: true

require "test_helper"

class ImportMediaOperationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @media_import = media_imports(:one) # status: 0 (pending)
  end

  test "successfully imports media and processes with fotheidil" do
    # Mock URI.open to avoid actual download
    mock_file = mock
    mock_file.stubs(:content_type).returns('audio/mpeg')
    mock_file.stubs(:read).returns('fake audio content')
    URI.stubs(:open).returns(mock_file)

    # Stub duration calculation since fake audio is invalid
    VoiceRecording.any_instance.stubs(:calculate_duration).returns(120.0)

    # Mock Fotheidil services used by subprocess
    browser_service = mock("browser_service")
    browser_service.stubs(:setup_browser).returns(true)
    browser_service.stubs(:authenticate).returns(true)
    browser_service.stubs(:cleanup)

    upload_service = mock("upload_service")
    upload_service.stubs(:upload_file).returns("https://fotheidil.abair.ie/videos/9999")

    parser_service = mock("parser_service")
    segments = [{"id" => "0001", "text" => "Test", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5}]
    parser_service.stubs(:parse_segments).returns(segments)

    create_speaker_entries_service = mock("create_speaker_entries_service")
    create_speaker_entries_service.stubs(:call)

    Fotheidil::BrowserService.stubs(:new).returns(browser_service)
    Fotheidil::UploadService.stubs(:new).returns(upload_service)
    Fotheidil::ParserService.stubs(:new).returns(parser_service)
    Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

    # Stub the wait and processing steps
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:post_process_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

    result = ImportMediaOperation.call(media_import_id: @media_import.id)

    assert result.success?, "Operation should succeed. Error: #{result[:error]}"
    assert_not_nil result[:voice_recording]
    assert_equal "#{@media_import.title} - #{@media_import.headline}", result[:voice_recording].title
  end

  test "fails when media import not found" do
    result = ImportMediaOperation.call(media_import_id: 999_999)

    assert_not result.success?
    assert_match(/not found/, result[:error])
  end

  test "skips when media import not pending" do
    @media_import.update!(status: :imported)

    result = ImportMediaOperation.call(media_import_id: @media_import.id)

    assert_not result.success?
    assert_match(/not pending/, result[:error])
  end

  test "reuses existing voice recording if found" do
    # Create existing recording with media attached
    generated_name = "#{@media_import.title} - #{@media_import.headline}"
    existing = VoiceRecording.create!(
      title: generated_name,
      owner: @user,
      diarization_status: "processing"
    )
    # Attach dummy media
    existing.media.attach(
      io: File.open(Rails.root.join("test/fixtures/files/deasaigh.mp3")),
      filename: "deasaigh.mp3"
    )

    # Mock Fotheidil services
    browser_service = mock("browser_service")
    browser_service.stubs(:setup_browser).returns(true)
    browser_service.stubs(:authenticate).returns(true)
    browser_service.stubs(:cleanup)

    upload_service = mock("upload_service")
    upload_service.stubs(:upload_file).returns("https://fotheidil.abair.ie/videos/9999")

    parser_service = mock("parser_service")
    segments = [{"id" => "0001", "text" => "Test", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5}]
    parser_service.stubs(:parse_segments).returns(segments)

    create_speaker_entries_service = mock("create_speaker_entries_service")
    create_speaker_entries_service.stubs(:call)

    Fotheidil::BrowserService.stubs(:new).returns(browser_service)
    Fotheidil::UploadService.stubs(:new).returns(upload_service)
    Fotheidil::ParserService.stubs(:new).returns(parser_service)
    Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:post_process_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

    result = ImportMediaOperation.call(media_import_id: @media_import.id)

    assert result.success?
    assert_equal existing.id, result[:voice_recording].id
  end

  test "skips if existing recording already completed" do
    # Reload to ensure we have fresh state (fixtures are shared across tests)
    @media_import.reload

    # Create completed recording
    generated_name = "#{@media_import.title} - #{@media_import.headline}"
    VoiceRecording.create!(
      title: generated_name,
      owner: @user,
      diarization_status: "completed"
    )

    result = ImportMediaOperation.call(media_import_id: @media_import.id)

    assert_not result.success?
    assert_match(/already exists and is completed/, result[:error])
  end

  test "marks media import as failed on error" do
    # Mock URI.open to avoid actual download
    mock_file = mock
    mock_file.stubs(:content_type).returns('audio/mpeg')
    mock_file.stubs(:read).returns('fake audio content')
    URI.stubs(:open).returns(mock_file)

    # Mock browser service to fail authentication
    browser_service = mock("browser_service")
    browser_service.stubs(:setup_browser).returns(false)
    browser_service.stubs(:cleanup)

    Fotheidil::BrowserService.stubs(:new).returns(browser_service)

    result = ImportMediaOperation.call(media_import_id: @media_import.id)

    assert_not result.success?
    @media_import.reload
    assert_equal "failed", @media_import.status # mark_as_failed! keeps status as pending
    assert_not_nil @media_import.error_message
  end

  test "downloads and attaches media from URL" do
    # Mock the download
    mock_file = mock
    mock_file.stubs(:content_type).returns('audio/mpeg')
    mock_file.stubs(:read).returns('fake audio content')
    URI.stubs(:open).returns(mock_file)

    # Stub duration calculation
    VoiceRecording.any_instance.stubs(:calculate_duration).returns(120.0)

    # Mock Fotheidil services
    browser_service = mock("browser_service")
    browser_service.stubs(:setup_browser).returns(true)
    browser_service.stubs(:authenticate).returns(true)
    browser_service.stubs(:cleanup)

    upload_service = mock("upload_service")
    upload_service.stubs(:upload_file).returns("https://fotheidil.abair.ie/videos/9999")

    parser_service = mock("parser_service")
    segments = [{"id" => "0001", "text" => "Test", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5}]
    parser_service.stubs(:parse_segments).returns(segments)

    create_speaker_entries_service = mock("create_speaker_entries_service")
    create_speaker_entries_service.stubs(:call)

    Fotheidil::BrowserService.stubs(:new).returns(browser_service)
    Fotheidil::UploadService.stubs(:new).returns(upload_service)
    Fotheidil::ParserService.stubs(:new).returns(parser_service)
    Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:post_process_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

    result = ImportMediaOperation.call(media_import_id: @media_import.id)

    assert result.success?, "Operation should succeed. Error: #{result[:error]}"
    voice_recording = result[:voice_recording]
    assert voice_recording.media.attached?, "Media should be attached"
  end

  test "downloads media for existing recording without media" do
    # Create existing recording WITHOUT media attached
    generated_name = "#{@media_import.title} - #{@media_import.headline}"
    existing = VoiceRecording.create!(
      title: generated_name,
      owner: @user,
      diarization_status: "processing"
    )
    # Note: No media attached!

    # Mock the download
    mock_file = mock
    mock_file.stubs(:content_type).returns('audio/mpeg')
    mock_file.stubs(:read).returns('fake audio content')
    URI.stubs(:open).returns(mock_file)

    # Stub duration calculation
    VoiceRecording.any_instance.stubs(:calculate_duration).returns(120.0)

    # Mock Fotheidil services
    browser_service = mock("browser_service")
    browser_service.stubs(:setup_browser).returns(true)
    browser_service.stubs(:authenticate).returns(true)
    browser_service.stubs(:cleanup)

    upload_service = mock("upload_service")
    upload_service.stubs(:upload_file).returns("https://fotheidil.abair.ie/videos/9999")

    parser_service = mock("parser_service")
    segments = [{"id" => "0001", "text" => "Test", "speaker" => "SPEAKER_00", "startTimeSeconds" => 0.5, "endTimeSeconds" => 2.5}]
    parser_service.stubs(:parse_segments).returns(segments)

    create_speaker_entries_service = mock("create_speaker_entries_service")
    create_speaker_entries_service.stubs(:call)

    Fotheidil::BrowserService.stubs(:new).returns(browser_service)
    Fotheidil::UploadService.stubs(:new).returns(upload_service)
    Fotheidil::ParserService.stubs(:new).returns(parser_service)
    Fotheidil::CreateSpeakerEntriesService.stubs(:new).returns(create_speaker_entries_service)

    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_transcription).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_segments).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:wait_for_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:post_process_entries).returns(true)
    Fotheidil::ProcessVideoOperation.any_instance.stubs(:publish).returns(true)

    result = ImportMediaOperation.call(media_import_id: @media_import.id)

    assert result.success?, "Operation should succeed. Error: #{result[:error]}"
    existing.reload
    assert existing.media.attached?, "Media should be downloaded and attached to existing recording"
    assert_equal existing.id, result[:voice_recording].id
  end
end
