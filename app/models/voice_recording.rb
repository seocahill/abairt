# frozen_string_literal: true

class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_one_attached :audio_track
  has_many :dictionary_entries
  has_many :users, -> { distinct }, through: :dictionary_entries, source: :speaker, class_name: "User"

  belongs_to :owner, class_name: "User", foreign_key: "user_id"
  belongs_to :location, optional: true

  has_many :voice_recording_locations, dependent: :destroy
  has_many :locations, through: :voice_recording_locations

  acts_as_taggable_on :tags

  # Provide direct access to diarization_data JSON fields
  store_accessor :diarization_data, :segments, :source, :fotheidil_video_id, :diarization

  # Analyze transcript for location/speaker metadata
  def analyze_transcript
    AnalyzeVoiceRecordingJob.perform_later(self)
  end

  def analyzed?
    metadata_analysis.present?
  end

  def dialect_region
    metadata_analysis&.dig("dialect_region")
  end

  def analysis_topics
    metadata_analysis&.dig("topics") || []
  end

  def analysis_speakers
    metadata_analysis&.dig("speakers") || []
  end

  def dialect_evidence
    metadata_analysis&.dig("dialect_evidence") || []
  end

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

  def segments_count
    return 0 unless diarization_data.present?

    # Prefer Fotheidil segments over pyannote diarization
    (diarization_data["segments"] || diarization_data["diarization"])&.size || 0
  end

  def calculate_duration(path)
    result = `ffprobe -i  #{path} -v quiet -print_format json -show_format -show_streams -hide_banner`
    JSON.parse(result).dig("format", "duration").to_f
  rescue => e
    # Return nil (not the truthy result of Logger#warn) so callers can rely on
    # `duration&.positive?` instead of crashing on `true.positive?`.
    Rails.logger.warn(["Duration calculation failed", e])
    nil
  end

  def percentage_transcribed
    return 0 if duration_seconds.zero?
    return 0 if dictionary_entries_count.zero?

    # add pading between entries 0.5 seconds + sum of regions as percentage of duration.
    percentage = (((dictionary_entries_count - 1) * 0.5) + dictionary_entries.sum("region_end - region_start")).fdiv(duration_seconds).*(100).round
    percentage.clamp(0, 100)
  end

  def extract_audio_track
    return unless media.attached?
    return media unless media.content_type.start_with?("video/")
    return audio_track if audio_track.attached?

    Tempfile.create(["audio", ".mp3"], binmode: true) do |temp_audio|
      media.open do |file|
        system(
          "ffmpeg", "-i", file.path,
          "-vn",                   # Disable video processing
          "-acodec", "libmp3lame", # MP3
          "-b:a", "128k",          # CBR 128kbps — avoids browser VBR timing drift
          "-y",                    # Overwrite output file
          temp_audio.path
        )

        audio_track.attach(
          io: File.open(temp_audio.path),
          filename: "#{media.filename.base}.mp3",
          content_type: "audio/mpeg"
        )
      end
    end

    audio_track
  rescue => e
    Rails.logger.error("Audio conversion error: #{e.message}")
    raise
  end

  # Import a new voice recording from the archive
  def self.import_from_archive
    ArchiveImportService.new.import_next_recording
  end

  # Import a specific MediaImport item
  def self.import_from_media_import(media_import_id)
    ArchiveImportService.new.import_specific_recording(media_import_id)
  end

  def completed?
    return false if dictionary_entries_count.zero?

    fully_transcribed? && fully_translated?
  end

  def fully_transcribed?
    return false if segments.blank? && diarization.blank?

    dictionary_entries_count >= expected_entries_count
  end

  # Segments count minus those legitimately skipped because a human entry
  # already covers that time range (Fotheidil overlap guard).
  def expected_entries_count
    source = segments || diarization
    return 0 if source.blank?

    source.count - segments_covered_by_human_entries
  end

  def fully_translated?
    dictionary_entries.where.not(translation: [nil, ""]).count.fdiv(dictionary_entries.count).*(100).round >= 75
  end

  private

  def segments_covered_by_human_entries
    return 0 unless segments.present?

    human_entries = dictionary_entries
      .where.not(speaker: User.where(role: :temporary))
      .where.not(region_start: nil)
      .where.not(region_end: nil)
      .to_a
    return 0 if human_entries.empty?

    segments.count do |seg|
      seg_start = seg["startTimeSeconds"]
      seg_end = seg["endTimeSeconds"]
      next false unless seg_start && seg_end

      human_entries.any? { |e| e.region_start < seg_end && e.region_end > seg_start }
    end
  end
end
