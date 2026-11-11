require "test_helper"

class AudioBlobTest < ActiveSupport::TestCase
  test "returns base64 of a WAV for a real file" do
    blob = AudioBlob.wav_base64(Rails.root.join("test/fixtures/files/deasaigh.mp3"))

    assert_equal "RIFF", Base64.decode64(blob)[0, 4]
  end

  test "treats shell metacharacters in the path as part of the filename" do
    marker = Rails.root.join("tmp/audio_blob_injected")
    FileUtils.rm_f(marker)

    assert_raises(RuntimeError) { AudioBlob.wav_base64("x\"; touch #{marker}; echo \"") }
    assert_not File.exist?(marker)
  end
end
