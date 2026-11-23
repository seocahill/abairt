# frozen_string_literal: true

require "test_helper"

class Transcription::RerunOperationTest < ActiveSupport::TestCase
  setup do
    @recording = voice_recordings(:two)
    @recording.update!(
      fotheidil_video_id: "old-job",
      segments: [{"id" => "1", "startTimeSeconds" => 0.0, "endTimeSeconds" => 5.0, "text" => "current text", "speaker" => "SPEAKER_00"}]
    )
    @recording.media.attach(io: File.open(file_fixture("deasaigh.mp3")), filename: "deasaigh.mp3", content_type: "audio/mpeg")

    @unconfirmed = place(dictionary_entries(:one), 0.0, 5.0, "current text")
    @confirmed = place(dictionary_entries(:two), 5.0, 10.0, "confirmed text")
    @run = TranscriptionRun.create!(voice_recording: @recording, requested_by: users(:admin))

    @api = mock("api_service")
    Fotheidil::ApiService.stubs(:new).returns(@api)
  end

  def place(entry, from, to, text)
    entry.update_columns(voice_recording_id: @recording.id, region_start: from, region_end: to, word_or_phrase: text)
    entry
  end

  def segment(from, to, text)
    {"id" => "#{from}-#{to}", "startTimeSeconds" => from, "endTimeSeconds" => to, "text" => text, "speaker" => "SPEAKER_00"}
  end

  def fresh_transcript
    [segment(0.0, 5.0, "fresh text"), segment(5.0, 10.0, "fresh confirmed"), segment(12.0, 14.0, "a new line")]
  end

  def rerun(**options)
    Transcription::RerunOperation.call(transcription_run: @run, interval: 0, **options)
  end

  # Everything a re-run must leave alone.
  def snapshot
    @recording.reload
    entries = @recording.dictionary_entries.order(:id).map { |e| e.attributes.slice("word_or_phrase", "translation", "accuracy_status", "updated_at") }
    attachments = ActiveStorage::Attachment.where(record: @recording).order(:id).pluck(:name, :blob_id)
    {recording: @recording.attributes.except("updated_at"), entries:, attachments:, versions: PaperTrail::Version.count, recordings: VoiceRecording.count}
  end

  test "submits the audio as a new job and never reuses the recording's job" do
    @api.expects(:submit).once.with { |path, file_name:| File.exist?(path) && file_name.start_with?("deasaigh-") }.returns(9001)
    @api.expects(:transcript).with("9001").returns(fresh_transcript)
    @api.expects(:transcript).with("old-job").never

    result = rerun

    assert result.success?, result[:error]
    assert_equal "9001", @run.reload.fotheidil_video_id
  end

  test "submits again on every run" do
    @api.expects(:submit).twice.returns(9001, 9002)
    @api.stubs(:transcript).returns(fresh_transcript)

    rerun
    @run.dismiss_pending(by: users(:admin)) # a recording has one open run at a time
    @run = TranscriptionRun.create!(voice_recording: @recording, requested_by: users(:admin))
    rerun

    assert_equal %w[9001 9002], TranscriptionRun.order(:id).pluck(:fotheidil_video_id)
  end

  test "a finished run keeps the transcript exactly as returned, and its candidates" do
    raw = fresh_transcript + [{"id" => "x", "text" => "no timings"}]
    @api.stubs(:submit).returns(9001)
    @api.stubs(:transcript).returns(raw)

    freeze_time do
      assert rerun.success?

      @run.reload
      assert @run.ready?
      assert_equal raw, @run.segments
      assert_equal Time.current, @run.started_at
      assert_equal Time.current, @run.finished_at
    end

    candidates = @run.transcription_candidates.order(:region_start)
    assert_equal [["differs", @unconfirmed, "fresh text"], ["differs", @confirmed, "fresh confirmed"], ["new_segment", nil, "a new line"]],
      candidates.map { |c| [c.kind, c.dictionary_entry, c.word_or_phrase] }
    assert candidates.all?(&:pending?)
  end

  test "never changes the recording, its segments or its entries, confirmed or not" do
    @api.stubs(:submit).returns(9001)
    @api.stubs(:transcript).returns(fresh_transcript)
    before = snapshot

    assert rerun.success?

    assert_equal before, snapshot
    assert_equal "current text", @unconfirmed.reload.word_or_phrase
    assert_equal "confirmed text", @confirmed.reload.word_or_phrase
    assert_equal "old-job", @recording.fotheidil_video_id
  end

  test "a failed transcription marks the run failed and leaves the recording as it was" do
    @api.stubs(:submit).returns(9001)
    @api.stubs(:transcript).raises(Fotheidil::ApiService::Error, "Abair API 500: boom")
    before = snapshot

    result = rerun

    assert_not result.success?
    assert @run.reload.failed?
    assert_includes @run.error, "500"
    assert_equal "9001", @run.fotheidil_video_id
    assert @run.finished_at
    assert_empty @run.transcription_candidates
    assert_equal before, snapshot
  end

  test "a failed upload marks the run failed without a job" do
    @api.stubs(:submit).raises(Fotheidil::ApiService::Error, "Abair API 413: too large")

    result = rerun

    assert_not result.success?
    assert @run.reload.failed?
    assert_nil @run.fotheidil_video_id
    assert_includes @run.error, "Upload error"
  end

  test "an empty transcript fails the run" do
    @api.stubs(:submit).returns(9001)
    @api.stubs(:transcript).returns([])

    assert_not rerun.success?
    assert @run.reload.failed?
    assert_equal "No segments found", @run.error
  end

  test "times out when the transcript never arrives" do
    @api.stubs(:submit).returns(9001)
    @api.stubs(:transcript).returns(nil)

    assert_not rerun(timeout: -1).success?
    assert @run.reload.failed?
    assert_includes @run.error, "Timeout"
  end

  test "a job id some recording already holds is refused" do
    voice_recordings(:one).update!(fotheidil_video_id: "9001")
    @api.stubs(:submit).returns(9001)
    @api.expects(:transcript).never

    assert_not rerun.success?
    assert @run.reload.failed?
    assert_nil @run.fotheidil_video_id
    assert_includes @run.error, "Fotheidil returned job 9001"
    assert_includes @run.error, "new Fotheidil job"
  end

  test "a run can still be closed after a recording takes its job id" do
    @api.stubs(:submit).returns(9001)
    @api.stubs(:transcript).with { voice_recordings(:one).update!(fotheidil_video_id: "9001") }.returns([])

    assert_not rerun.success?
    assert @run.reload.failed?
    assert_equal "9001", @run.fotheidil_video_id
  end

  test "a failure while matching keeps the segments, saves no candidates and fails the run" do
    @api.stubs(:submit).returns(9001)
    @api.stubs(:transcript).returns(fresh_transcript)
    Transcription::MatchCandidates.stubs(:call).raises(ActiveRecord::RecordInvalid)

    assert_not rerun.success?
    assert @run.reload.failed?
    assert_equal fresh_transcript, @run.segments
    assert_empty @run.transcription_candidates
  end

  test "a pending run that already has its own job waits for it instead of submitting again" do
    @run.update!(fotheidil_video_id: "9001", started_at: 1.hour.ago)
    @api.expects(:submit).never
    @api.expects(:transcript).with("9001").twice.returns(nil, fresh_transcript)

    assert rerun.success?
    assert @run.reload.ready?
  end

  test "a finished run is not run again" do
    @run.update!(status: :ready, fotheidil_video_id: "9001", finished_at: Time.current)
    @api.expects(:submit).never

    result = rerun

    assert_not result.success?
    assert_equal "Run #{@run.id} is already ready", result[:error]
    assert @run.reload.ready?
  end

  test "a recording without media fails the run" do
    @recording.media.purge

    assert_not rerun.success?
    assert @run.reload.failed?
    assert_equal "Voice recording must have media attached", @run.error
  end
end
