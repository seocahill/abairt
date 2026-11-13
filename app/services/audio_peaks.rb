# frozen_string_literal: true

require "open3"

# Reduces an audio (or video) file to the min/max peaks wavesurfer.js draws, so
# the player can show a waveform without downloading and decoding the whole
# recording. ffmpeg is called with an argument array, so the path never goes
# through a shell.
#
# Returns { "samples_per_second" => 8, "data" => [min0, max0, min1, max1, ...] }
# with values in -1.0..1.0, the pre-decoded format wavesurfer accepts.
class AudioPeaks
  SAMPLE_RATE = 8000
  PEAKS_PER_SECOND = 8
  WINDOW = SAMPLE_RATE / PEAKS_PER_SECOND
  BYTES_PER_SAMPLE = 2

  def self.call(path)
    new(path).call
  end

  def initialize(path)
    @path = path.to_s
  end

  def call
    data = []
    Open3.popen3(*command) do |stdin, stdout, stderr, thread|
      stdout.binmode
      stdin.close
      stderr_reader = Thread.new { stderr.read }
      read_peaks(stdout, data)
      raise "ffmpeg failed (exit #{thread.value.exitstatus}): #{stderr_reader.value.lines.last(3).join}" unless thread.value.success?
    end

    raise "no audio found in #{File.basename(@path)}" if data.empty?

    {"samples_per_second" => PEAKS_PER_SECOND, "data" => data}
  end

  private

  def command
    ["ffmpeg", "-v", "error", "-i", @path, "-vn", "-ac", "1", "-ar", SAMPLE_RATE.to_s, "-f", "s16le", "-"]
  end

  # Streams the PCM so a 79 minute recording never sits in memory whole.
  def read_peaks(io, data)
    while (chunk = io.read(WINDOW * BYTES_PER_SAMPLE))
      samples = chunk.unpack("s<*")
      data << (samples.min / 32768.0).round(2) << (samples.max / 32767.0).round(2)
    end
  end
end
