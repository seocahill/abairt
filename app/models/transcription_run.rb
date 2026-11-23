# frozen_string_literal: true

# One fresh ASR run of a whole recording (#133). Its output is kept here as raw
# segments and turned into candidates for a person to accept or dismiss; a run
# never writes to the recording's own segments or to its entries.
#
# Every run is a new Fotheidil job, so its video id is never one a recording
# already has and never another run's.
class TranscriptionRun < ApplicationRecord
  belongs_to :voice_recording
  belongs_to :requested_by, class_name: "User"

  has_many :transcription_candidates, dependent: :delete_all

  enum :status, {pending: 0, ready: 1, failed: 2}

  validates :fotheidil_video_id, uniqueness: true, allow_nil: true
  validates :fotheidil_video_id, presence: true, if: :ready?
  validates :finished_at, presence: true, unless: :pending?
  validate :segments_is_a_list
  validate :new_fotheidil_job, if: :fotheidil_video_id_changed?
  validate :finished_after_started
  validate :one_open_run_per_recording, on: :create

  # The job waits at most half an hour for its transcript and holds its slot
  # for an hour; a run still pending well after that was lost (a deploy or a
  # killed worker) and will never finish.
  ABANDONED_AFTER = 2.hours

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :abandoned, -> { pending.where(created_at: ...ABANDONED_AFTER.ago) }

  def abandoned?
    pending? && created_at.present? && created_at < ABANDONED_AFTER.ago
  end

  # Closes a lost run as failed so the recording can be re-transcribed again.
  # Its recording and entries are untouched, as with any failed run.
  def abandon!
    update!(status: :failed, error: "No result after #{ABANDONED_AFTER.inspect}; the job was lost", finished_at: Time.current)
  end

  # Dismisses every candidate still waiting ("Dismiss run"). Returns how many.
  def dismiss_pending(by:)
    transaction { transcription_candidates.pending.to_a.count { |candidate| candidate.dismiss(by:) } }
  end

  # Pending candidates by kind, e.g. {"differs" => 3, "new_segment" => 1}.
  def pending_counts
    @pending_counts ||= transcription_candidates.pending.group(:kind).count
  end

  # Current lines nothing in the new transcription lined up with.
  def unheard_entries
    voice_recording.dictionary_entries.where(id: unheard_entry_ids).order(:region_start, :id)
  end

  def awaiting_review?
    ready? && pending_counts.values.sum.positive?
  end

  private

  def segments_is_a_list
    errors.add(:segments, "must be a list") unless segments.is_a?(Array)
  end

  # Recordings copied by the old retranscribe button share the original's id,
  # so any recording holding it counts, not only this one. Checked when the id
  # is set, so the run can still be closed if a recording takes the id later.
  def new_fotheidil_job
    return if fotheidil_video_id.blank?
    return unless VoiceRecording.where("json_extract(diarization_data, '$.fotheidil_video_id') = ?", fotheidil_video_id.to_s).exists?

    errors.add(:fotheidil_video_id, "must be a new Fotheidil job, not one a recording already has")
  end

  # A recording has one re-transcription at a time: a new one waits until the
  # last has finished and been reviewed, so no candidate is left unseen.
  def one_open_run_per_recording
    return if voice_recording.blank?

    others = voice_recording.transcription_runs.where.not(id: id)
    if others.pending.where(created_at: ABANDONED_AFTER.ago..).exists?
      errors.add(:base, "A re-transcription of this recording is already running")
    elsif others.ready.joins(:transcription_candidates).merge(TranscriptionCandidate.pending).exists?
      errors.add(:base, "Review or dismiss the last re-transcription of this recording first")
    end
  end

  def finished_after_started
    return if started_at.blank? || finished_at.blank?

    errors.add(:finished_at, "can't be before it started") if finished_at < started_at
  end
end
