# frozen_string_literal: true

class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_one_attached :audio_track
  has_many :dictionary_entries
  has_many :users, -> { distinct }, through: :dictionary_entries, source: :speaker, class_name: "User"

  belongs_to :owner, class_name: "User", foreign_key: "user_id"
  belongs_to :location, optional: true

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
    return 0 unless diarization_data.present? && diarization_data["diarization"].present?
    diarization_data["diarization"].size
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
    percentage.clamp(0, 100)
  end

  def extract_audio_track
    return unless media.attached?
    return media unless media.content_type.start_with?("video/")
    return audio_track if audio_track.attached?

    Tempfile.create(["audio", ".wav"], binmode: true) do |temp_audio|
      media.open do |file|
        # Use ffmpeg to extract audio track to WAV format
        system(
          "ffmpeg", "-i", file.path,
          "-vn",        # Disable video processing
          "-acodec", "pcm_s16le",  # PCM 16-bit little-endian
          "-ar", "44100",          # Sample rate
          "-ac", "2",              # Stereo audio
          "-y",                    # Overwrite output file
          temp_audio.path
        )

        # Attach the audio file
        audio_track.attach(
          io: File.open(temp_audio.path),
          filename: "#{media.filename.base}.wav",
          content_type: "audio/wav"
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
    # segments refers to newer fotheidil format, diarization refers to older pyannote format
    return false if segments.blank? && diarization.blank?
    
    dictionary_entries_count >= (segments || diarization).count
  end

  def fully_translated?
    dictionary_entries.where.not(translation: [nil, ""]).count.fdiv(dictionary_entries.count).*(100).round >= 75
  end
end
