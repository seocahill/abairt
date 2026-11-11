# frozen_string_literal: true

require "open3"

# Converts an audio file to the base64 mono 16kHz WAV that the abair.ie ASR API
# expects. ffmpeg is called with an argument array, so the path never goes
# through a shell.
class AudioBlob
  def self.wav_base64(path)
    new(path).wav_base64
  end

  def initialize(path)
    @path = path.to_s
  end

  def wav_base64
    wav, stderr, status = Open3.capture3(
      "ffmpeg", "-i", @path, "-f", "wav", "-acodec", "pcm_s16le", "-ac", "1", "-ar", "16000", "-",
      binmode: true
    )
    raise "ffmpeg failed (exit #{status.exitstatus}): #{stderr.lines.last(3).join}" unless status.success?

    Base64.encode64(wav)
  end
end
