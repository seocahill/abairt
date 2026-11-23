require "test_helper"

# The review flow for re-transcriptions (#133, f133_retranscribe): starting a
# run, the review page, accepting or dismissing lines, accept all and dismiss.
class TranscriptionRunsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @owner = users(:two)
    @recording = voice_recordings(:two)
    @recording.dictionary_entries.destroy_all
    @recording.media.attach(io: File.open(file_fixture("sample.mp3")), filename: "sample.mp3", content_type: "audio/mpeg")
    @entry = DictionaryEntry.create!(voice_recording: @recording, owner: @owner, word_or_phrase: "old words here",
      translation: "the translation", region_start: 1, region_end: 3)
    @confirmed = DictionaryEntry.create!(voice_recording: @recording, owner: @owner, word_or_phrase: "checked line",
      translation: "checked", region_start: 4, region_end: 6, accuracy_status: :confirmed)
    sign_in_as @owner
    Flipper.enable(:f133_retranscribe)
  end

  def sign_in_as(user)
    ApplicationController.any_instance.stubs(:current_user).returns(user)
  end

  def ready_run
    run = TranscriptionRun.create!(voice_recording: @recording, requested_by: @owner)
    run.update!(status: :ready, fotheidil_video_id: "rerun-1", started_at: 1.minute.ago, finished_at: Time.current)
    @differs = run.transcription_candidates.create!(dictionary_entry: @entry, region_start: 1, region_end: 3, word_or_phrase: "new words here")
    @locked = run.transcription_candidates.create!(dictionary_entry: @confirmed, region_start: 4, region_end: 6, word_or_phrase: "checked lime")
    @added = run.transcription_candidates.create!(kind: :new_segment, region_start: 8, region_end: 9, word_or_phrase: "a new line")
    run
  end

  test "with the flag off none of it is there" do
    Flipper.disable(:f133_retranscribe)
    run = ready_run

    post voice_recording_transcription_runs_url(@recording)
    assert_response :not_found
    get transcription_run_url(run)
    assert_response :not_found
    patch transcription_candidate_url(@differs), params: {transcription_candidate: {status: "accepted"}}
    assert_response :not_found
    post transcription_run_acceptance_url(run)
    assert_response :not_found
    post transcription_run_dismissal_url(run)
    assert_response :not_found
    post transcription_run_timing_url(run)
    assert_response :not_found
    assert_equal "old words here", @entry.reload.word_or_phrase
  end

  test "the owner starts a re-run: a new run and its job, no duplicate recording" do
    assert_no_difference -> { VoiceRecording.count } do
      assert_enqueued_with(job: TranscriptionRerunJob) do
        post voice_recording_transcription_runs_url(@recording)
      end
    end

    run = @recording.transcription_runs.sole
    assert run.pending?
    assert_equal @owner, run.requested_by
    assert_redirected_to voice_recording_url(@recording)
    assert_match(/Re-transcription started/, flash[:notice])
  end

  test "after starting one, Turbo following the redirect gets the recording page, not the next-page stream" do
    post voice_recording_transcription_runs_url(@recording), as: :turbo_stream
    get response.location, headers: {"Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"}

    assert_equal "text/html", response.media_type
    assert_select "#transcription_run_status", /Re-transcribing/
  end

  test "the infinite scroll still gets its next-page stream" do
    get voice_recording_url(@recording, page: 1), as: :turbo_stream
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "an admin may start one too" do
    sign_in_as users(:admin)
    post voice_recording_transcription_runs_url(@recording)
    assert_equal 1, @recording.transcription_runs.count
  end

  test "anybody else may not start one" do
    sign_in_as users(:one)
    assert_no_enqueued_jobs only: TranscriptionRerunJob do
      post voice_recording_transcription_runs_url(@recording)
    end
    assert_equal 0, @recording.transcription_runs.count
  end

  test "a recording without audio can't be re-transcribed" do
    @recording.media.purge
    post voice_recording_transcription_runs_url(@recording)
    assert_equal 0, @recording.transcription_runs.count
    assert_match(/no audio/, flash[:alert])
  end

  test "a second run waits until the last is reviewed" do
    ready_run
    post voice_recording_transcription_runs_url(@recording)
    assert_equal 1, @recording.transcription_runs.count
    assert_match(/Review or dismiss/, flash[:alert])
  end

  test "the review page shows each line beside the current one, with its choices" do
    run = ready_run
    get transcription_run_url(run)
    assert_response :success

    assert_select "[data-testid=rerun-counts]", /2 lines differ, 1 new/
    assert_select "##{ActionView::RecordIdentifier.dom_id(@differs)}" do
      assert_select "[data-testid=current-text] del", "old"
      assert_select "[data-testid=new-text] ins", "new"
      assert_select "button", "Use new"
      assert_select "button", "Keep current"
      assert_select "input[name='transcription_candidate[current_text]'][value='old words here']"
      assert_select "button[data-controller=audio-player][data-audio-player-start-value='1.0'][data-audio-player-end-value='3.0']"
    end
    assert_select "##{ActionView::RecordIdentifier.dom_id(@locked)}" do
      assert_select "p", /Deconfirm it first/
      assert_select "button", text: "Use new", count: 0
      assert_select "button", "Keep current"
    end
    assert_select "##{ActionView::RecordIdentifier.dom_id(@added)}" do
      assert_select "button", "Add as line"
      assert_select "button", "Dismiss"
    end
    assert_select "button", "Accept all (1)"
    assert_select "button", "Dismiss run"
  end

  test "only an admin or the owner sees the review page" do
    run = ready_run
    sign_in_as users(:one)
    get transcription_run_url(run)
    assert_response :redirect
    assert_match(/sínithe/, flash[:alert])
  end

  test "use new changes the entry, keeps its translation and marks it as possibly out of date" do
    run = ready_run
    patch transcription_candidate_url(@differs), params: {transcription_candidate: {status: "accepted", current_text: "old words here"}}, as: :turbo_stream

    assert_response :success
    assert_equal ["new words here", "the translation"], @entry.reload.slice(:word_or_phrase, :translation).values
    assert @differs.reload.accepted?
    assert_includes response.body, "Used new text"
    assert_includes response.body, "Irish text changed since this translation was made"
    assert_includes response.body, %(id="transcription_run_summary")
    assert_equal "old words here", @entry.versions.last.reify.word_or_phrase

    get voice_recording_url(@recording)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@entry)} [data-testid=stale-translation]"
    assert_select "##{ActionView::RecordIdentifier.dom_id(@confirmed)} [data-testid=stale-translation]", count: 0
    assert run.reload.awaiting_review?
  end

  test "keep current changes nothing on the entry" do
    ready_run
    patch transcription_candidate_url(@differs), params: {transcription_candidate: {status: "dismissed"}}, as: :turbo_stream

    assert_response :success
    assert @differs.reload.dismissed?
    assert_equal "old words here", @entry.reload.word_or_phrase
    assert_includes response.body, "Kept current"
  end

  test "a confirmed line can't be replaced through the flow" do
    ready_run
    patch transcription_candidate_url(@locked), params: {transcription_candidate: {status: "accepted", current_text: "checked line"}}, as: :turbo_stream

    assert_response :unprocessable_content
    assert_includes response.body, "Deconfirm it first"
    assert_equal "checked line", @confirmed.reload.word_or_phrase
    assert @locked.reload.pending?
  end

  test "add as line creates an unconfirmed entry" do
    ready_run
    assert_difference -> { @recording.dictionary_entries.count }, 1 do
      patch transcription_candidate_url(@added), params: {transcription_candidate: {status: "accepted"}}, as: :turbo_stream
    end
    assert_response :success
    assert @added.reload.dictionary_entry.unconfirmed?
    assert_includes response.body, "Added as a line"
  end

  test "an unknown choice changes nothing" do
    ready_run
    patch transcription_candidate_url(@differs), params: {transcription_candidate: {status: "pending"}}, as: :turbo_stream
    assert_response :unprocessable_content
    assert @differs.reload.pending?
  end

  test "only an admin or the owner may accept a line" do
    ready_run
    sign_in_as users(:one)
    patch transcription_candidate_url(@differs), params: {transcription_candidate: {status: "accepted"}}
    assert_equal "old words here", @entry.reload.word_or_phrase
    assert @differs.reload.pending?
  end

  test "accept all uses the new text on unconfirmed lines only" do
    run = ready_run
    post transcription_run_acceptance_url(run), params: {seen_at: 1.minute.from_now.to_r.to_s}

    assert_redirected_to transcription_run_url(run)
    assert_match(/1 line/, flash[:notice])
    assert_equal "new words here", @entry.reload.word_or_phrase
    assert_equal "checked line", @confirmed.reload.word_or_phrase
    assert @added.reload.pending?
  end

  test "accept all leaves lines changed since the page was loaded, and says so" do
    run = ready_run
    get transcription_run_url(run)
    seen_at = css_select("form[action='#{transcription_run_acceptance_path(run)}'] input[name=seen_at]").first["value"]
    travel 1.second
    @entry.update!(word_or_phrase: "a correction meanwhile")

    post transcription_run_acceptance_url(run), params: {seen_at:}
    assert_equal "a correction meanwhile", @entry.reload.word_or_phrase
    assert_match(/1 line changed since you opened the page/, flash[:notice])
  end

  test "accept all without a page time changes nothing" do
    run = ready_run
    post transcription_run_acceptance_url(run), params: {seen_at: "garbage"}
    assert_equal "old words here", @entry.reload.word_or_phrase
  end

  test "resolving one line keeps the page's load time on accept all" do
    ready_run
    seen_at = 5.minutes.ago.to_r.to_s
    patch transcription_candidate_url(@added), params: {transcription_candidate: {status: "dismissed"}, seen_at:}, as: :turbo_stream
    assert_includes response.body, %(name="seen_at" value="#{seen_at}")
  end

  test "a run lost while pending is closed when a new one starts" do
    lost = TranscriptionRun.create!(voice_recording: @recording, requested_by: @owner, created_at: 3.hours.ago)
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status", /never finished/
    assert_select "#transcription_run_status button", "Re-transcribe"

    post voice_recording_transcription_runs_url(@recording)
    assert lost.reload.failed?
    assert_equal 1, @recording.transcription_runs.pending.count
  end

  test "dismiss run dismisses what is left and changes nothing" do
    run = ready_run
    post transcription_run_dismissal_url(run)

    assert_redirected_to voice_recording_url(@recording)
    assert run.transcription_candidates.all?(&:dismissed?)
    assert_equal ["old words here", "checked line"], @recording.dictionary_entries.order(:region_start).pluck(:word_or_phrase)
  end

  test "strangers can't accept all or dismiss" do
    run = ready_run
    sign_in_as users(:one)
    post transcription_run_acceptance_url(run)
    post transcription_run_dismissal_url(run)
    assert run.transcription_candidates.all?(&:pending?)
  end

  test "the recording page shows the owner how to start one" do
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status button", "Re-transcribe"
  end

  test "the old duplicate-the-recording button is hidden only while the flag is on" do
    @recording.update!(owner: users(:admin))
    sign_in_as users(:admin)
    get voice_recording_url(@recording)
    assert_select "form[action='#{retranscribe_voice_recording_path(@recording)}']", count: 0

    Flipper.disable(:f133_retranscribe)
    get voice_recording_url(@recording)
    assert_select "form[action='#{retranscribe_voice_recording_path(@recording)}']", count: 1
  end

  test "the recording page says when a run is ready to review" do
    run = ready_run
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status [data-testid=rerun-summary]", /2 lines differ, 1 new/
    assert_select "#transcription_run_status a[href='#{transcription_run_path(run)}']", "Review"
  end

  test "the recording page says when a run is under way or failed" do
    run = TranscriptionRun.create!(voice_recording: @recording, requested_by: @owner)
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status", /Re-transcribing/
    assert_select "#transcription_run_status button", count: 0

    run.update!(status: :failed, error: "Upload error: timeout", finished_at: Time.current)
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status", /Upload error: timeout/
    assert_select "#transcription_run_status button", "Re-transcribe"
  end

  test "nobody else sees it on the recording page" do
    sign_in_as users(:one)
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status", count: 0
  end

  test "with the flag off the recording page is as before" do
    Flipper.disable(:f133_retranscribe)
    ready_run
    @differs.update!(status: :accepted, resolved_by: @owner, resolved_at: Time.current, translation_at_acceptance: "the translation")
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status", count: 0
    assert_select "[data-testid=stale-translation]", count: 0
  end

  test "the flag is on for admins" do
    Flipper.disable(:f133_retranscribe)
    Flipper.enable_group(:f133_retranscribe, :admins)
    sign_in_as users(:admin)
    get voice_recording_url(@recording)
    assert_select "#transcription_run_status button", "Re-transcribe"
  end

  # A run with a line that has no times (text typed in or copied from
  # elsewhere), a line that differs only in case, and a line not heard.
  def run_with_copied_lines
    run = TranscriptionRun.create!(voice_recording: @recording, requested_by: @owner)
    run.update!(status: :ready, fotheidil_video_id: "rerun-2", started_at: 1.minute.ago, finished_at: Time.current)
    @copied = DictionaryEntry.create!(voice_recording: @recording, owner: @owner, word_or_phrase: "copied line", translation: "its translation")
    @silent = DictionaryEntry.create!(voice_recording: @recording, owner: @owner, word_or_phrase: "nobody said this", region_start: 20, region_end: 22)
    @cosmetic = DictionaryEntry.create!(voice_recording: @recording, owner: @owner, word_or_phrase: "tá sé go maith", region_start: 30, region_end: 32)
    @timing = run.transcription_candidates.create!(kind: :timing, dictionary_entry: @copied, region_start: 12.5, region_end: 17.25, word_or_phrase: "copied line")
    @cosmetic_candidate = run.transcription_candidates.create!(dictionary_entry: @cosmetic, region_start: 30, region_end: 32, word_or_phrase: "Tá sé go maith.")
    run.update!(unheard_entry_ids: [@silent.id])
    run
  end

  test "the review page offers to set times, with the text left alone, and lists the lines not heard" do
    run = run_with_copied_lines
    get transcription_run_url(run)
    assert_response :success

    assert_select "[data-testid=rerun-counts]", /1 line differs, 0 new, 1 needs times/
    assert_select "##{ActionView::RecordIdentifier.dom_id(@timing)}" do
      assert_select "[data-testid=timing-text]", "copied line"
      assert_select "button", "Set times"
      assert_select "button", "Dismiss"
      assert_select "button[data-controller=audio-player][data-audio-player-start-value='12.5'][data-audio-player-end-value='17.25']"
    end
    assert_select "button", "Set all times (1)"
    assert_select "[data-testid=unheard]" do
      assert_select "li", text: /nobody said this/
      assert_select "li", text: /copied line/, count: 0
    end
  end

  test "setting times on a line gives it times and leaves its text" do
    run = run_with_copied_lines
    patch transcription_candidate_url(@timing), params: {transcription_candidate: {status: "accepted"}, seen_at: Time.current.to_r.to_s}, as: :turbo_stream

    assert_response :success
    assert_equal [12.5, 17.25, "copied line", "its translation"], @copied.reload.slice(:region_start, :region_end, :word_or_phrase, :translation).values.map { it.is_a?(BigDecimal) ? it.to_f : it }
    assert_includes response.body, "Times set"
    assert_not_includes response.body, "Irish text changed since this translation was made"
    assert_includes response.body, %(id="transcription_run_summary")
    assert run.reload.transcription_candidates.timing.sole.accepted?
  end

  test "set all times gives times to every line without them and changes no text" do
    run = run_with_copied_lines
    assert_enqueued_with(job: EntryAudioSnippetJob) do
      post transcription_run_timing_url(run), params: {seen_at: Time.current.to_r.to_s}
    end

    assert_redirected_to transcription_run_url(run)
    assert_match(/Gave times to 1 line/, flash[:notice])
    assert_equal 12.5, @copied.reload.region_start
    assert_equal "copied line", @copied.word_or_phrase
    assert_equal "tá sé go maith", @cosmetic.reload.word_or_phrase
  end

  test "only an admin or the owner may set all times" do
    run = run_with_copied_lines
    sign_in_as users(:one)
    post transcription_run_timing_url(run)
    assert_response :redirect
    assert_nil @copied.reload.region_start
  end

  test "lines that differ only in case or punctuation can be hidden, and are left by accept all while hidden" do
    run = run_with_copied_lines
    get transcription_run_url(run)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@cosmetic_candidate)}", /Case or punctuation only/
    assert_select "a", /Hide lines that differ only in case or punctuation/

    get transcription_run_url(run, hide_cosmetic: 1)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@cosmetic_candidate)}", count: 0
    assert_select "a", "Show them"
    assert_select "button", text: /Accept all/, count: 0
    assert_select "input[name=hide_cosmetic][value='1']"

    post transcription_run_acceptance_url(run), params: {seen_at: 1.minute.from_now.to_r.to_s, hide_cosmetic: "1"}
    assert_redirected_to transcription_run_url(run, hide_cosmetic: "1")
    assert_equal "tá sé go maith", @cosmetic.reload.word_or_phrase

    post transcription_run_acceptance_url(run), params: {seen_at: 1.minute.from_now.to_r.to_s}
    assert_equal "Tá sé go maith.", @cosmetic.reload.word_or_phrase
  end

  test "a line decided while hidden stays on the page" do
    run = run_with_copied_lines
    patch transcription_candidate_url(@cosmetic_candidate), params: {transcription_candidate: {status: "dismissed"}, hide_cosmetic: "1", seen_at: Time.current.to_r.to_s}
    assert_redirected_to transcription_run_url(run, hide_cosmetic: "1")
    get transcription_run_url(run, hide_cosmetic: 1)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@cosmetic_candidate)}", /Kept current/
  end
end
