require "test_helper"

class AudioPeaksTest < ActiveSupport::TestCase
  test "reduces audio to min/max pairs at eight per second" do
    peaks = AudioPeaks.call(file_fixture("sample.mp3"))
    data = peaks["data"]

    assert_equal 8, peaks["samples_per_second"]
    assert_predicate data, :any?
    assert_predicate data.size, :even?
    assert data.all? { |v| v.between?(-1.0, 1.0) }
    assert data.each_slice(2).all? { |min, max| min <= max }
  end

  test "raises when ffmpeg cannot read the file" do
    assert_raises(RuntimeError) { AudioPeaks.call(file_fixture("fotheidil_video_1141_segments.json")) }
  end
end
