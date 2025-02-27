# frozen_string_literal: true
class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_one_attached :audio_track
  has_many :dictionary_entries
  has_many :users, -> { distinct }, through: :dictionary_entries, source: :speaker, class_name: 'User'
  has_many :learning_sessions, as: :learnable
  # after_commit :enqueue_generate_peaks_job # FIXME: payload is too big in browser
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

  def enqueue_generate_peaks_job
    return unless media.changed? || peaks.blank?

    GeneratePeaksJob.perform_later(id)
  end

  def enqueue_diarization_job
    DiarizeVoiceRecordingJob.perform_later(id)
  end

  def should_diarize?
    media.attached? && (diarization_status.nil? || diarization_status == 'not_started')
  end

  def generate_peaks
    require 'open3'
    # Set the output file path and delete cache
    output_path = "/tmp/#{media.key}.json"
    File.delete output_path rescue nil
    media.open do |file|
      # Extract the selected region and save it as a new MP3 file using ffmpeg
      # audiowaveform -i input.mp3 -o output.json
      Rails.logger.debug file.path
      # ffmpeg -i test.mp4 -f wav - | audiowaveform --input-format wav --output-format dat -b 8 > test.dat
      stdout, stderr, status = Open3.capture3("ffmpeg -i #{file.path} -f mp3 -  | audiowaveform --input-format mp3 -o #{output_path}")
      # Attach the new file to a Recording model using Active Storage
      Rails.logger.debug [stdout, stderr, status]
    end
    json_data = File.read(output_path)
    peak_data = JSON.parse(json_data)
    self.peaks = peak_data['data']
    self.duration_seconds = calculate_duration(file.path)
    save
  rescue => e
    Rails.logger.warn(["Peak generation failed", e])
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
end
