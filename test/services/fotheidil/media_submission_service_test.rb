# frozen_string_literal: true

require "test_helper"

class Fotheidil::MediaSubmissionServiceTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:two)
    @recording.media.attach(io: File.open(file_fixture("deasaigh.mp3")), filename: "deasaigh.mp3", content_type: "audio/mpeg")
    @api = mock("api_service")
  end

  # Records what was uploaded while the temporary file still exists.
  def capture_upload(job_id = 9001)
    uploads = []
    @api.stubs(:submit).with do |path, file_name:|
      uploads << {path:, file_name:, bytes: File.binread(path)}
    end.returns(job_id)
    uploads
  end

  def submit
    Fotheidil::MediaSubmissionService.new(@recording, api: @api).call
  end

  test "returns the new job id as a string" do
    capture_upload(9001)
    assert_equal "9001", submit
  end

  test "uploads the media when there is no audio track, without adding one" do
    uploads = capture_upload

    submit

    assert_equal file_fixture("deasaigh.mp3").binread, uploads.sole[:bytes]
    assert_not @recording.reload.audio_track.attached?
  end

  test "uploads the downsampled audio track when the recording has one" do
    @recording.audio_track.attach(io: File.open(file_fixture("sample.mp3")), filename: "sample.mp3", content_type: "audio/mpeg")
    uploads = capture_upload

    submit

    assert_equal file_fixture("sample.mp3").binread, uploads.sole[:bytes]
    assert uploads.sole[:file_name].end_with?(".mp3")
  end

  test "gives every submission a different file name from the media's own" do
    uploads = capture_upload

    2.times { submit }

    names = uploads.pluck(:file_name)
    assert names.all? { |name| name.match?(/\Adeasaigh-\h{8}\.mp3\z/) }, names.inspect
    assert_equal 2, names.uniq.size
  end

  test "removes its temporary files" do
    uploads = capture_upload

    submit

    assert_not File.exist?(uploads.sole[:path])
  end

  test "extracts the audio from a video before uploading" do
    @recording.media.attach(io: StringIO.new("video bytes"), filename: "clip.mp4", content_type: "video/mp4")
    Fotheidil::MediaSubmissionService.any_instance.expects(:system).with do |*args, **|
      args.first == "ffmpeg" && args.include?("-vn") && File.write(args[-1], "audio bytes")
    end.returns(true)
    uploads = capture_upload

    submit

    assert_match(/\Aclip-\h{8}\.mp3\z/, uploads.sole[:file_name])
    assert_equal "audio bytes", uploads.sole[:bytes]
  end

  test "uploads the video itself if the audio can't be extracted" do
    @recording.media.attach(io: StringIO.new("video bytes"), filename: "clip.mp4", content_type: "video/mp4")
    Fotheidil::MediaSubmissionService.any_instance.stubs(:system).returns(false)
    uploads = capture_upload

    submit

    assert_match(/\Aclip-\h{8}\.mp4\z/, uploads.sole[:file_name])
    assert_equal "video bytes", uploads.sole[:bytes]
  end

  test "passes on the api's error" do
    @api.stubs(:submit).raises(Fotheidil::ApiService::Error, "Abair API 413: too large")

    assert_raises(Fotheidil::ApiService::Error) { submit }
  end
end
