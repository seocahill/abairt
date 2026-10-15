require "test_helper"

class OpusVoiceNoteTest < ActiveSupport::TestCase
  def attachment_for(path, content_type, identify: true)
    question = Question.new(asker: users(:two), speaker: users(:speaker))
    question.audio.attach(
      io: Rails.root.join(path).open,
      filename: File.basename(path),
      content_type: content_type,
      identify: identify
    )
    question.save!
    question.audio
  end

  # WhatsApp renders ogg/opus as a playable voice bubble and anything else as a
  # file attachment, so this is the guarantee the speaker's whole experience
  # rests on.
  test "produces an ogg/opus file from an mp3" do
    audio = attachment_for("test/fixtures/files/sample.mp3", "audio/mpeg")

    OpusVoiceNote.new(audio).open do |path|
      assert File.size?(path).present?
      assert_match(/Opus/i, `ffprobe -hide_banner #{path} 2>&1`)
    end
  end

  test "passes ogg straight through without re-encoding" do
    audio = attachment_for("test/fixtures/files/sample.mp3", "audio/ogg", identify: false)

    OpusVoiceNote.new(audio).open do |path|
      # Content type says ogg, so it is handed over untouched — no temp file.
      assert_match(/\.mp3\z/, path)
    end
  end
end
