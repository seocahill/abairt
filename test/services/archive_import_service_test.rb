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

  test "import_next_recording delegates to ImportMediaOperation" do
    # Create a MediaImport record
    media_import = MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/123",
      title: "Turas Siar 123",
      headline: "Pap le MTS: Tairngreacht Bhriain Rua",
      description: "Test description",
      status: :pending
    )

    # Mock the operation result
    mock_voice_recording = VoiceRecording.new(id: 1, title: "Test")
    mock_result = mock
    mock_result.stubs(:success?).returns(true)
    mock_result.stubs(:[]).with(:voice_recording).returns(mock_voice_recording)

    ImportMediaOperation.stubs(:call).returns(mock_result)

    voice_recording = @service.import_next_recording

    assert_equal mock_voice_recording, voice_recording
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

  test "import_specific_recording delegates to ImportMediaOperation" do
    # Create a MediaImport record
    media_import = MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/456",
      title: "Turas Siar 456",
      headline: "Test Specific Import",
      description: "Test specific description",
      status: :pending
    )

    # Mock the operation result
    mock_voice_recording = VoiceRecording.new(id: 2, title: "Test Specific")
    mock_result = mock
    mock_result.stubs(:success?).returns(true)
    mock_result.stubs(:[]).with(:voice_recording).returns(mock_voice_recording)

    ImportMediaOperation.stubs(:call).with(media_import_id: media_import.id).returns(mock_result)

    voice_recording = @service.import_specific_recording(media_import.id)

    assert_equal mock_voice_recording, voice_recording
  end

  test "import_specific_recording returns nil when operation fails" do
    # Create a MediaImport record
    media_import = MediaImport.create!(
      url: "https://archive-turas-siar.s3.eu-west-1.amazonaws.com/p/av/789",
      title: "Turas Siar 789",
      headline: "Failed Import",
      description: "Failed description",
      status: :pending
    )

    # Mock failed operation result
    mock_result = mock
    mock_result.stubs(:success?).returns(false)
    mock_result.stubs(:[]).with(:error).returns("Some error")

    ImportMediaOperation.stubs(:call).with(media_import_id: media_import.id).returns(mock_result)

    assert_nil @service.import_specific_recording(media_import.id)
  end
end 