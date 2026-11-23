# frozen_string_literal: true

module Transcription
  # Re-transcribes a whole recording into a TranscriptionRun (#133): submits
  # the audio to Fotheidil as a new job, waits for it, keeps the raw segments
  # on the run and lines them up with the current entries as candidates.
  #
  # It never writes to the recording, its segments or its entries; a person
  # accepts or dismisses each candidate later. A run that fails keeps its
  # error and leaves the recording exactly as it was.
  #
  # The audio is always submitted again, never matched to a job a recording
  # already has (which would only re-fetch the old transcript). A pending run
  # that already holds its own new job, because the worker stopped while
  # waiting, picks that job up instead of submitting a second one.
  #
  #   run = TranscriptionRun.create!(voice_recording: recording, requested_by: user)
  #   result = Transcription::RerunOperation.call(transcription_run: run)
  #   result.success? # run.ready?, with run.transcription_candidates
  #   result[:error]  # also saved on run.error when it fails
  class RerunOperation < Trailblazer::Operation
    include Fotheidil::TranscriptSteps

    step :validate_run
    step :start
    step :submit_audio
    step :wait_for_transcription
    step :parse_segments
    step :save_segments
    step :match_candidates
    step :finish
    left :mark_as_failed

    def validate_run(ctx, transcription_run:, **)
      ctx[:error] = if !transcription_run.pending?
        "Run #{transcription_run.id} is already #{transcription_run.status}"
      elsif !transcription_run.voice_recording.media.attached?
        "Voice recording must have media attached"
      end

      ctx[:error].nil?
    end

    def start(ctx, transcription_run:, **)
      transcription_run.update!(started_at: Time.current) if transcription_run.started_at.nil?
      true
    end

    def submit_audio(ctx, transcription_run:, **)
      if transcription_run.fotheidil_video_id.blank?
        job_id = Fotheidil::MediaSubmissionService.new(transcription_run.voice_recording).call
        transcription_run.update!(fotheidil_video_id: job_id)
      end

      ctx[:fotheidil_video_id] = transcription_run.fotheidil_video_id
      true
    rescue => e
      ctx[:error] = "Upload error: #{e.message}"
      false
    end

    def save_segments(ctx, transcription_run:, segments:, **)
      transcription_run.update!(segments:)
      true
    rescue => e
      ctx[:error] = "Failed to save segments: #{e.message}"
      false
    end

    # Saves every candidate or none (MatchCandidates works in one transaction).
    def match_candidates(ctx, transcription_run:, **)
      ctx[:candidates] = MatchCandidates.call(transcription_run)
      true
    rescue => e
      ctx[:error] = "Failed to match segments to entries: #{e.message}"
      false
    end

    def finish(ctx, transcription_run:, **)
      transcription_run.update!(status: :ready, finished_at: Time.current)
      true
    rescue => e
      ctx[:error] = "Failed to finish the run: #{e.message}"
      false
    end

    # Closes a pending run as failed with its error, dropping whatever change
    # didn't save. A run that was already finished is left as it is. The
    # recording is never touched.
    def mark_as_failed(ctx, transcription_run:, **)
      Rails.logger.error "Re-transcription failed for TranscriptionRun##{transcription_run.id}: #{ctx[:error]}"
      transcription_run.restore_attributes
      return true unless transcription_run.pending?

      transcription_run.update!(status: :failed, error: ctx[:error], finished_at: Time.current)
      true
    end
  end
end
