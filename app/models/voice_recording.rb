class VoiceRecording < ApplicationRecord
  has_one_attached :media
  has_many :conversations, dependent: :destroy
  has_many :users, through: :conversations
  has_many :dictionary_entries
  before_save :generate_peaks

  accepts_nested_attributes_for :conversations

  acts_as_taggable_on :tags

  def meeting_id
    SecureRandom.uuid
  end

  def generate_peaks
    require 'open3'

    return unless media.changed? || peaks.blank?
    # Set the output file path and delete cache
    output_path = "/tmp/#{media.key}.json"
    File.delete output_path rescue nil
    media.open do |file|
      # Extract the selected region and save it as a new MP3 file using ffmpeg
      # audiowaveform -i input.mp3 -o output.json
      puts file.path
      # ffmpeg -i test.mp4 -f wav - | audiowaveform --input-format wav --output-format dat -b 8 > test.dat
      stdout, stderr, status = Open3.capture3("ffmpeg -i #{file.path} -f mp3 -  | audiowaveform --input-format mp3 -o #{output_path}")
      # Attach the new file to a Recording model using Active Storage
      puts [stdout, stderr, status]
    end
    json_data = File.read(output_path)
    peak_data = JSON.parse(json_data)
    self.peaks = peak_data['data']
  rescue => e
    Rails.logger.warn(["Peak generation failed", e])
  end
end
