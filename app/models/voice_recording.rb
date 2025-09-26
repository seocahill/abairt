# frozen_string_literal: true
class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_one_attached :audio_track
  has_many :dictionary_entries
  has_many :users, -> { distinct }, through: :dictionary_entries, source: :speaker, class_name: 'User'
  after_create_commit :enqueue_diarization_job, if: :should_diarize?

  belongs_to :owner, class_name: "User", foreign_key: "user_id"

  acts_as_taggable_on :tags

  alias_attribute :name, :title

  def next
    VoiceRecording.where("id > ?", id).first
  end

  def prev
    VoiceRecording.where("id < ?", id).last
  end

  def meeting_id
    SecureRandom.uuid
  end

  def enqueue_diarization_job
    DiarizeVoiceRecordingJob.perform_later(id)
  end

  def should_diarize?
    media.attached? && (diarization_status.nil? || diarization_status == 'not_started')
  end

  def segments_count
    return 0 unless diarization_data.present? && diarization_data['diarization'].present?
    diarization_data['diarization'].size
  end

  def calculate_duration(path)
    result = `ffprobe -i  #{path} -v quiet -print_format json -show_format -show_streams -hide_banner`
    JSON.parse(result).dig("format", "duration").to_f
  rescue => e
    Rails.logger.warn(["Duration calculation failed", e])
  end

  def percentage_transcribed
    return 0 if duration_seconds.zero?
    return 0 if dictionary_entries_count.zero?

    # add pading between entries 0.5 seconds + sum of regions as percentage of duration.
    percentage = (((dictionary_entries_count - 1) * 0.5) + dictionary_entries.sum("region_end - region_start")).fdiv(duration_seconds).*(100).round
    if percentage > 100
      100
    elsif percentage < 0
      0
    else
      percentage
    end
  end

  def extract_audio_track
    return unless media.attached?
    return media unless media.content_type.start_with?('video/')
    return audio_track if audio_track.attached?

    Tempfile.create(['audio', '.wav'], binmode: true) do |temp_audio|
      media.open do |file|
        # Use ffmpeg to extract audio track to WAV format
        system(
          'ffmpeg', '-i', file.path,
          '-vn',        # Disable video processing
          '-acodec', 'pcm_s16le',  # PCM 16-bit little-endian
          '-ar', '44100',          # Sample rate
          '-ac', '2',              # Stereo audio
          '-y',                    # Overwrite output file
          temp_audio.path
        )

        # Attach the audio file
        audio_track.attach(
          io: File.open(temp_audio.path),
          filename: "#{media.filename.base}.wav",
          content_type: 'audio/wav'
        )
      end
    end

    audio_track
  rescue => e
    Rails.logger.error("Audio conversion error: #{e.message}")
    raise
  end

  # Import a new voice recording from the archive
  def self.import_from_archive(media_file_path: nil)
    ArchiveImportService.new(media_file_path: media_file_path).import_next_recording
  end
end
