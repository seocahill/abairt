require "test_helper"

class GeneratePeaksJobTest < ActiveJob::TestCase
  test "stores peaks on the recording" do
    recording = voice_recordings(:one)
    recording.media.attach(io: file_fixture("sample.mp3").open, filename: "sample.mp3", content_type: "audio/mpeg")

    GeneratePeaksJob.perform_now(recording.id)

    assert_predicate recording.reload.peaks["data"], :any?
  end

  test "does nothing for a recording without media" do
    recording = voice_recordings(:one)
    recording.media.purge
    recording.update!(peaks: nil)

    assert_nil recording.generate_peaks
    assert_nil recording.reload.peaks
  end
end
