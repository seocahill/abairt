class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_many :dictionary_entries
  has_many :users, -> { distinct }, through: :dictionary_entries, source: :speaker, class_name: 'User'
  has_many :learning_sessions, as: :learnable
  after_commit :enqueue_generate_peaks_job

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
    save
  rescue => e
    Rails.logger.warn(["Peak generation failed", e])
  end
end
