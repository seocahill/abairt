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
  validate :new_fotheidil_job
  validate :finished_after_started

  scope :newest_first, -> { order(created_at: :desc) }

  private

  def segments_is_a_list
    errors.add(:segments, "must be a list") unless segments.is_a?(Array)
  end

  # Recordings copied by the old retranscribe button share the original's id,
  # so any recording holding it counts, not only this one.
  def new_fotheidil_job
    return if fotheidil_video_id.blank?
    return unless VoiceRecording.where("json_extract(diarization_data, '$.fotheidil_video_id') = ?", fotheidil_video_id.to_s).exists?

    errors.add(:fotheidil_video_id, "must be a new Fotheidil job, not one a recording already has")
  end

  def finished_after_started
    return if started_at.blank? || finished_at.blank?

    errors.add(:finished_at, "can't be before it started") if finished_at < started_at
  end
end
